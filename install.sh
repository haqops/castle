#!/usr/bin/env bash
# Bootstrap a castle host via nixos-anywhere in one shot: generate the initrd
# SSH host key, generate the main SSH host key (which doubles as the sops age
# identity), populate any missing sops secrets, and install NixOS with the
# whole thing already wired up.
#
# Usage:
#   ./install.sh <host> [ip]
# If [ip] is omitted, it is read from ./hosts.nix.

set -euo pipefail

HOST="${1:?host name required, e.g. citadel}"
IP="${2:-}"

for f in flake.nix hosts.nix; do
  [[ -f "$f" ]] || { echo "!! $f not found in CWD (run from your instance repo)" >&2; exit 1; }
done

if [[ -z "$IP" ]]; then
  IP="$(nix --extra-experimental-features 'nix-command flakes' eval --raw --impure \
        --expr "(import ./hosts.nix ((builtins.getFlake (toString ./.)).inputs.castle)).${HOST}.castle.host.ipv4")"
fi
[[ -z "$IP" ]] && { echo "!! cannot resolve ipv4 for '$HOST'" >&2; exit 1; }

INITRD_KEY="secrets/${HOST}/initrd/ssh_host_ed25519_key"
SSH_KEY="secrets/${HOST}/ssh/ssh_host_ed25519_key"

if [[ ! -f "$INITRD_KEY" ]]; then
  echo ">> generating initrd host key at $INITRD_KEY"
  mkdir -p "$(dirname "$INITRD_KEY")"
  ssh-keygen -t ed25519 -N '' -C "${HOST}-initrd" -f "$INITRD_KEY" >/dev/null
fi

# Does the flake declare any sops secrets for this host?
SECRETS_COUNT="$(nix --extra-experimental-features 'nix-command flakes' eval --raw \
                  --apply 'attrs: toString (builtins.length (builtins.attrNames attrs))' \
                  ".#nixosConfigurations.${HOST}.config.sops.secrets" 2>/dev/null || echo 0)"

USE_SECRETS=0
if [[ "$SECRETS_COUNT" -gt 0 ]]; then
  USE_SECRETS=1
fi

if [[ $USE_SECRETS -eq 1 ]]; then
  [[ -f .sops.yaml ]] || { echo "!! .sops.yaml missing; needed because host declares sops secrets" >&2; exit 1; }

  if [[ ! -f "$SSH_KEY" ]]; then
    echo ">> generating main SSH host key at $SSH_KEY"
    mkdir -p "$(dirname "$SSH_KEY")"
    ssh-keygen -t ed25519 -N '' -C "${HOST}" -f "$SSH_KEY" >/dev/null
  fi

  AGE_RECIPIENT="$(ssh-to-age -i "${SSH_KEY}.pub")"
  echo ">> ${HOST} age recipient: ${AGE_RECIPIENT}"

  if ! grep -qF "$AGE_RECIPIENT" .sops.yaml; then
    echo
    echo "!! .sops.yaml does not include this host's age recipient."
    echo "   Add it to 'keys:' and to the creation_rules key_groups, e.g.:"
    echo
    echo "     - &${HOST} ${AGE_RECIPIENT}"
    echo
    echo "   Then re-run '$0 $HOST'."
    exit 1
  fi

  echo ">> checking sops secrets for ${HOST}"
  bash "$(dirname "$0")/secrets.sh" "$HOST"
fi

EXTRA="$(mktemp -d)"
trap 'rm -rf "$EXTRA"' EXIT

install -Dm 0400 "$INITRD_KEY"     "$EXTRA/etc/secrets/initrd/ssh_host_ed25519_key"
install -Dm 0444 "${INITRD_KEY}.pub" "$EXTRA/etc/secrets/initrd/ssh_host_ed25519_key.pub"

if [[ $USE_SECRETS -eq 1 ]]; then
  install -Dm 0400 "$SSH_KEY"     "$EXTRA/etc/ssh/ssh_host_ed25519_key"
  install -Dm 0444 "${SSH_KEY}.pub" "$EXTRA/etc/ssh/ssh_host_ed25519_key.pub"
fi

echo
echo ">> installing ${HOST} at ${IP}"
echo ">> ZFS passphrase will be prompted during install — remember it; you'll type it again on every boot via initrd SSH"
[[ $USE_SECRETS -eq 1 ]] && echo ">> sops secrets bundled; services will start on first boot"
echo

nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/nixos-anywhere -- \
    --flake ".#${HOST}" \
    --extra-files "$EXTRA" \
    "root@${IP}"
