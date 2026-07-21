#!/usr/bin/env bash
# Bootstrap a castle host via nixos-anywhere.
# Run from a farm repo (CWD contains flake.nix + hosts.nix).
#
# Usage:
#   ./install.sh <host> [ip]
# If [ip] is omitted, it is read from ./hosts.nix.

set -euo pipefail

HOST="${1:?host name required, e.g. citadel}"
IP="${2:-}"

if [[ ! -f flake.nix ]]; then
  echo "!! run this from your farm repo (flake.nix must be in CWD)" >&2
  exit 1
fi

if [[ ! -f hosts.nix ]]; then
  echo "!! ./hosts.nix not found — copy hosts.example.nix and fill in real values" >&2
  exit 1
fi

if [[ -z "$IP" ]]; then
  IP="$(nix --extra-experimental-features 'nix-command flakes' eval --raw --impure \
        --expr "(import ./hosts.nix ((builtins.getFlake (toString ./.)).inputs.castle)).${HOST}.castle.host.ipv4")"
fi

if [[ -z "$IP" ]]; then
  echo "!! could not resolve ipv4 for host '$HOST'" >&2
  exit 1
fi

KEY_SRC="secrets/${HOST}/ssh_host_ed25519_key"
if [[ ! -f "$KEY_SRC" ]]; then
  echo ">> generating initrd host key at $KEY_SRC"
  mkdir -p "secrets/${HOST}"
  ssh-keygen -t ed25519 -N '' -C "${HOST}-initrd" -f "$KEY_SRC" >/dev/null
fi

EXTRA="$(mktemp -d)"
trap 'rm -rf "$EXTRA"' EXIT

install -Dm 0400 "$KEY_SRC"     "$EXTRA/etc/secrets/initrd/ssh_host_ed25519_key"
install -Dm 0444 "$KEY_SRC.pub" "$EXTRA/etc/secrets/initrd/ssh_host_ed25519_key.pub"

echo ">> installing ${HOST} at ${IP}"
echo ">> ZFS passphrase will be prompted during install — remember it, you'll type it again on every boot via initrd SSH"
echo

nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/nixos-anywhere -- \
    --flake ".#${HOST}" \
    --extra-files "$EXTRA" \
    "root@${IP}"
