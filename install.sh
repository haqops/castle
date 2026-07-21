#!/usr/bin/env bash
# Bootstrap or re-provision a castle host via nixos-anywhere.
#
# Generates local SSH host keys, syncs the sops recipient, fills any missing
# secrets, ships everything via --extra-files, kexecs the NixOS installer,
# then deletes the local private host-key material so it only lives on the
# target box.
#
# Usage:
#   ./install.sh <host> [ip] [--force]
# --force: allow overwriting a target that is already running NixOS.

set -euo pipefail

FORCE=0
POSARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --*)     echo "!! unknown flag: $1" >&2; exit 1 ;;
    *)       POSARGS+=("$1"); shift ;;
  esac
done

HOST="${POSARGS[0]:?host name required, e.g. citadel}"
IP="${POSARGS[1]:-}"

for f in flake.nix hosts.nix; do
  [[ -f "$f" ]] || { echo "!! $f not found in CWD (run from your instance repo)" >&2; exit 1; }
done

if [[ -z "$IP" ]]; then
  IP="$(nix --extra-experimental-features 'nix-command flakes' eval --raw --impure \
        --expr "(import ./hosts.nix ((builtins.getFlake (toString ./.)).inputs.castle)).${HOST}.castle.host.ipv4")"
fi
[[ -z "$IP" ]] && { echo "!! cannot resolve ipv4 for '$HOST'" >&2; exit 1; }

# Safety guard: refuse to wipe a target that is already NixOS unless --force.
if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
       "root@${IP}" 'test -f /etc/NIXOS' 2>/dev/null; then
  if [[ $FORCE -eq 0 ]]; then
    echo "!! ${IP} is already running NixOS."
    echo "   To reinstall (WIPES /dev/sda), pass --force:"
    echo "     $0 ${HOST} --force"
    exit 1
  fi
  echo ">> ${IP} is NixOS; --force set — proceeding with wipe + reinstall"
fi

INITRD_KEY="secrets/${HOST}/initrd/ssh_host_ed25519_key"
SSH_KEY="secrets/${HOST}/ssh/ssh_host_ed25519_key"

if [[ ! -f "$INITRD_KEY" ]]; then
  echo ">> generating initrd host key at $INITRD_KEY"
  mkdir -p "$(dirname "$INITRD_KEY")"
  ssh-keygen -t ed25519 -N '' -C "${HOST}-initrd" -f "$INITRD_KEY" >/dev/null
fi

SECRETS_COUNT="$(nix --extra-experimental-features 'nix-command flakes' eval --raw \
                  --apply 'attrs: toString (builtins.length (builtins.attrNames attrs))' \
                  ".#nixosConfigurations.${HOST}.config.sops.secrets" 2>/dev/null || echo 0)"

USE_SECRETS=0
[[ "$SECRETS_COUNT" -gt 0 ]] && USE_SECRETS=1

if [[ $USE_SECRETS -eq 1 ]]; then
  [[ -f .sops.yaml ]] || { echo "!! .sops.yaml missing; needed because host declares sops secrets" >&2; exit 1; }

  if [[ ! -f "$SSH_KEY" ]]; then
    echo ">> generating main SSH host key at $SSH_KEY"
    mkdir -p "$(dirname "$SSH_KEY")"
    ssh-keygen -t ed25519 -N '' -C "${HOST}" -f "$SSH_KEY" >/dev/null
  fi

  AGE_RECIPIENT="$(ssh-to-age -i "${SSH_KEY}.pub")"
  echo ">> ${HOST} age recipient: ${AGE_RECIPIENT}"

  if grep -qF "$AGE_RECIPIENT" .sops.yaml; then
    echo "   ✓ .sops.yaml already has this recipient"
  elif grep -qE "^  - &${HOST}[[:space:]]" .sops.yaml; then
    old="$(grep -oE "^  - &${HOST}[[:space:]]+age1[a-z0-9]+" .sops.yaml | awk '{print $NF}')"
    echo "   updating .sops.yaml anchor &${HOST}"
    echo "     old: ${old}"
    echo "     new: ${AGE_RECIPIENT}"
    sed -i -E "s|^(  - &${HOST}[[:space:]]+)age1[a-z0-9]+|\1${AGE_RECIPIENT}|" .sops.yaml
    if [[ -f "secrets/${HOST}.yaml" ]]; then
      echo "   re-encrypting secrets/${HOST}.yaml for new recipient set"
      sops updatekeys --yes "secrets/${HOST}.yaml"
    fi
  else
    echo
    echo "!! .sops.yaml does not have an anchor for '${HOST}' yet."
    echo "   Add these lines and re-run '$0 ${HOST}':"
    echo
    echo "     # under keys:"
    echo "     - &${HOST} ${AGE_RECIPIENT}"
    echo
    echo "     # under creation_rules, in the age list for secrets/${HOST}.yaml:"
    echo "     - *${HOST}"
    echo
    exit 1
  fi

  echo ">> checking sops secrets for ${HOST}"
  bash "$(dirname "$0")/update-secrets.sh" "$HOST"
fi

EXTRA="$(mktemp -d)"
trap 'rm -rf "$EXTRA"' EXIT

install -Dm 0400 "$INITRD_KEY"       "$EXTRA/etc/secrets/initrd/ssh_host_ed25519_key"
install -Dm 0444 "${INITRD_KEY}.pub" "$EXTRA/etc/secrets/initrd/ssh_host_ed25519_key.pub"

if [[ $USE_SECRETS -eq 1 ]]; then
  install -Dm 0400 "$SSH_KEY"       "$EXTRA/etc/ssh/ssh_host_ed25519_key"
  install -Dm 0444 "${SSH_KEY}.pub" "$EXTRA/etc/ssh/ssh_host_ed25519_key.pub"
fi

echo
echo ">> installing ${HOST} at ${IP}"
echo ">> ZFS passphrase will be prompted — remember it; you'll type it on every boot via initrd SSH"
[[ $USE_SECRETS -eq 1 ]] && echo ">> sops secrets bundled; services will start on first boot"
echo

nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/nixos-anywhere -- \
    --flake ".#${HOST}" \
    --extra-files "$EXTRA" \
    "root@${IP}"

# nixos-anywhere succeeded (set -e would have exited otherwise). The target
# now owns the private host-key material; delete the local copy.
echo
echo ">> install complete; removing local host keys (they live on ${HOST} now)"
rm -rf "secrets/${HOST}"
