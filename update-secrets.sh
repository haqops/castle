#!/usr/bin/env bash
# update-secrets — populate sops secrets for one or all hosts, interactively.
#
# Reads the list of expected secrets from
#   .#nixosConfigurations.<host>.config.sops.secrets
# and prompts for each one that is not yet set in secrets/<host>.yaml.
# Existing values are left untouched.
#
# Usage:
#   ./update-secrets.sh           iterate every host declared in the flake
#   ./update-secrets.sh <host>    just this one host
# Run from the instance repo (CWD contains flake.nix + .sops.yaml + hosts.nix).

set -euo pipefail

for f in flake.nix .sops.yaml; do
  [[ -f "$f" ]] || { echo "!! $f not found in CWD" >&2; exit 1; }
done

NIX=(nix --extra-experimental-features 'nix-command flakes')

# Human-readable descriptions for known keys; anything else falls back to a
# generic prompt.
declare -A DESCRIPTIONS=(
  ["caddy/origin.crt"]="Cloudflare Origin CA certificate (--BEGIN CERTIFICATE-- ...)"
  ["caddy/origin.key"]="Cloudflare Origin CA private key   (--BEGIN PRIVATE KEY-- ...)"
  ["discourse/secret-key-base"]="Rails secret_key_base (auto-generated)"
  ["discourse/s3-access-key-id"]="R2 / S3 Access Key ID"
  ["discourse/s3-secret-access-key"]="R2 / S3 Secret Access Key"
  ["discourse/smtp-password"]="SMTP password for the configured provider"
)

# Generators: keys with an entry here are filled automatically by running the
# command (no prompt). Users can still overwrite by editing the sops file
# directly with `sops secrets/<host>.yaml`.
declare -A GENERATORS=(
  ["discourse/secret-key-base"]="openssl rand -hex 64"
)

# Convert "a/b/c" -> ["a"]["b"]["c"] for sops --set / --extract.
sops_path() {
  local key="$1"
  printf '["%s"]' "${key//\//\"][\"}"
}

ensure_encrypted_file() {
  local file="$1"
  [[ -f "$file" ]] && return
  mkdir -p "$(dirname "$file")"
  local tmp; tmp="$(mktemp)"
  echo '{}' > "$tmp"
  sops --encrypt --input-type=json --filename-override "$file" "$tmp" > "$file"
  rm -f "$tmp"
}

process_host() {
  local host="$1"
  local secrets_file="secrets/${host}.yaml"

  echo "── ${host}"

  local secrets_out
  secrets_out=$("${NIX[@]}" eval --raw \
    --apply 'attrs: builtins.concatStringsSep "\n" (builtins.attrNames attrs)' \
    ".#nixosConfigurations.${host}.config.sops.secrets" 2>/dev/null || true)

  local -a secrets=()
  if [[ -n "$secrets_out" ]]; then
    mapfile -t secrets <<< "$secrets_out"
  fi

  if [[ ${#secrets[@]} -eq 0 ]]; then
    echo "   no sops secrets declared — skipping"
    echo
    return 0
  fi

  ensure_encrypted_file "$secrets_file"

  local -a missing=()
  local key path
  for key in "${secrets[@]}"; do
    path="$(sops_path "$key")"
    if sops --decrypt --extract "$path" "$secrets_file" >/dev/null 2>&1; then
      echo "   ✓ $key"
    else
      missing+=("$key")
    fi
  done

  if [[ ${#missing[@]} -eq 0 ]]; then
    echo "   all secrets present"
    echo
    return 0
  fi

  echo
  echo "   ${#missing[@]} secret(s) to fill:"
  for key in "${missing[@]}"; do echo "     $key"; done
  echo

  local description value escaped generator
  for key in "${missing[@]}"; do
    path="$(sops_path "$key")"
    description="${DESCRIPTIONS[$key]:-Value for $key}"
    generator="${GENERATORS[$key]:-}"

    echo "── ${host} :: $key"
    echo "   $description"

    if [[ -n "$generator" ]]; then
      value="$(eval "$generator")"
      if [[ -z "$value" ]]; then
        echo "   (generator '$generator' produced empty output — skipping)"
        echo
        continue
      fi
      echo "   auto-generated via: $generator"
    else
      echo "   Paste value; finish with Ctrl-D on empty line:"
      value="$(cat)"
      if [[ -z "$value" ]]; then
        echo "   (empty — skipping $key)"
        echo
        continue
      fi
    fi

    escaped="$(printf '%s' "$value" | jq -Rs '.')"
    sops --set "$path $escaped" "$secrets_file"
    echo "   ✓ written"
    echo
  done
}

if [[ $# -ge 1 ]]; then
  process_host "$1"
else
  hosts_out="$("${NIX[@]}" eval --raw \
    --apply 'attrs: builtins.concatStringsSep "\n" (builtins.attrNames attrs)' \
    '.#nixosConfigurations')"
  mapfile -t hosts <<< "$hosts_out"

  if [[ ${#hosts[@]} -eq 0 ]]; then
    echo "no hosts declared in this flake" >&2
    exit 1
  fi

  for h in "${hosts[@]}"; do
    process_host "$h"
  done
fi
