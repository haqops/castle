#!/usr/bin/env bash
# update-secrets — populate sops secrets for a host interactively.
#
# Reads the list of expected secrets from
#   .#nixosConfigurations.<host>.config.sops.secrets
# and prompts for each one that is not yet set in secrets/<host>.yaml.
# Existing values are left untouched.
#
# Usage: ./update-secrets.sh <host>
# Run from the instance repo (CWD contains flake.nix + .sops.yaml + hosts.nix).

set -euo pipefail

HOST="${1:?host name required, e.g. citadel}"

for f in flake.nix .sops.yaml; do
  [[ -f "$f" ]] || { echo "!! $f not found in CWD" >&2; exit 1; }
done

SECRETS_FILE="secrets/${HOST}.yaml"

# Human-readable descriptions for known keys; anything else falls back to a
# generic prompt. Extend as more services join castle.
declare -A DESCRIPTIONS=(
  ["caddy/origin.crt"]="Cloudflare Origin CA certificate (--BEGIN CERTIFICATE-- ...)"
  ["caddy/origin.key"]="Cloudflare Origin CA private key   (--BEGIN PRIVATE KEY-- ...)"
)

# Convert "a/b/c" -> ["a"]["b"]["c"] for sops --set / --extract.
sops_path() {
  local key="$1"
  printf '["%s"]' "${key//\//\"][\"}"
}

ensure_encrypted_file() {
  [[ -f "$SECRETS_FILE" ]] && return
  mkdir -p "$(dirname "$SECRETS_FILE")"
  local tmp
  tmp="$(mktemp)"
  echo '{}' > "$tmp"
  sops --encrypt --input-type=json --filename-override "$SECRETS_FILE" "$tmp" > "$SECRETS_FILE"
  rm -f "$tmp"
}

# Get list of secrets from the NixOS config.
mapfile -t SECRETS < <(
  nix --extra-experimental-features 'nix-command flakes' eval --raw \
    --apply 'attrs: builtins.concatStringsSep "\n" (builtins.attrNames attrs)' \
    ".#nixosConfigurations.${HOST}.config.sops.secrets"
)

if [[ ${#SECRETS[@]} -eq 0 ]]; then
  echo "no sops secrets declared for $HOST — nothing to do"
  exit 0
fi

ensure_encrypted_file

missing=()
for key in "${SECRETS[@]}"; do
  path="$(sops_path "$key")"
  if sops --decrypt --extract "$path" "$SECRETS_FILE" >/dev/null 2>&1; then
    echo "✓ $key — already set"
  else
    missing+=("$key")
  fi
done

if [[ ${#missing[@]} -eq 0 ]]; then
  echo
  echo "All secrets already present. Nothing to prompt for."
  exit 0
fi

echo
echo "── ${#missing[@]} secret(s) to fill:"
for key in "${missing[@]}"; do echo "     $key"; done
echo

for key in "${missing[@]}"; do
  path="$(sops_path "$key")"
  description="${DESCRIPTIONS[$key]:-Value for $key}"

  echo "── $key"
  echo "   $description"
  echo "   Paste value; finish with Ctrl-D on empty line:"
  value="$(cat)"

  if [[ -z "$value" ]]; then
    echo "   (empty — skipping $key)"
    echo
    continue
  fi

  escaped="$(printf '%s' "$value" | jq -Rs '.')"
  sops --set "$path $escaped" "$SECRETS_FILE"
  echo "   ✓ written"
  echo
done

echo "Done. secrets/${HOST}.yaml updated."
