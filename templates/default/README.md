# your castle

A private registry of your hosts, users, and secrets — built on top of the
[castle](https://github.com/haqops/castle) library.

## Files

- `flake.nix` — instance flake; imports castle, builds `nixosConfigurations`
  and `deploy.nodes` from `hosts.nix`.
- `hosts.nix` — the whole castle: hosts, users, service configuration.
- `.sops.yaml` — recipients config (age keys that can decrypt secrets).
- `secrets/<host>.yaml` — sops-encrypted secrets for a host. Safe to commit.
- `secrets/<host>/` — SSH host keys (gitignored).
- `.envrc` — direnv auto-activates the devShell on `cd`.

## Prerequisites

- Nix with flakes enabled.
- direnv (optional, but recommended).
- Your own age key at `~/.config/sops/age/keys.txt`. If you don't have one:
  ```sh
  mkdir -p ~/.config/sops/age
  nix shell nixpkgs#age -c age-keygen -o ~/.config/sops/age/keys.txt
  # public key is on the '# public key: age1…' line
  ```
- For public web services: a Cloudflare account with your zone under
  management.

## Enter the shell

```sh
cd my-castle
nix develop   # or just cd if direnv is set up
```

Commands in the devShell:

- `install-host <name>` — provision a fresh box: generate keys, plant
  secrets, kexec a NixOS installer, activate services.
- `update-secrets <name>` — interactively fill missing sops secrets for a
  host. Existing values are never overwritten.
- `deploy .#<name>` — build + activate current config on a host. Rolls
  back automatically on failure.

## Adding a host

Add an entry to `hosts.nix`. Minimum for a Hetzner Cloud VM:

```nix
citadel = {
  castle.host.ipv4    = "203.0.113.42";
  castle.host.sshKeys = [ "ssh-ed25519 AAAA... you@laptop" ];
};
```

For bare metal or non-Hetzner, opt out of the built-in defaults and provide
your own disko + hardware config — see the examples in `hosts.nix`.

## Adding users

`castle.users` is a global registry. Every service that has its own
accounts (currently just Forgejo) provisions the same list.

```nix
castle.users = {
  admin = { email = "admin@example.com"; admin = true; };
  alice = { email = "alice@example.com"; };
};
```

Each user gets one password shared across services, stored at sops key
`users/<name>/password`. `update-secrets` will prompt for missing ones.

Users are created on first activation. Passwords, emails, admin flags
changed later in `hosts.nix` are **not** synced back to services — this is
create-only, no destructive updates. Delete a user in the service's UI if
you want it gone.

## Adding a service: Forgejo

```nix
citadel = {
  # ...host stuff, castle.users...
  sops.defaultSopsFile = ./secrets/citadel.yaml;

  castle.services.forgejo = {
    enable = true;
    domain = "git.example.com";
  };
};
```

Turning on Forgejo auto-enables Caddy and PostgreSQL and provisions
accounts for every entry in `castle.users`.

## Cloudflare (one-time per zone)

Reverse proxy in castle expects a Cloudflare Origin CA certificate — no
Let's Encrypt, no renewal loop.

1. **Cloudflare dashboard → your zone → SSL/TLS → Origin Server → Create
   Certificate.** Hosts: `*.example.com` and `example.com`. Type: ECC.
   Validity: 15 years. Save the certificate and private key text.
2. **SSL/TLS → Overview → mode: Full (strict).**
3. **DNS.** For each service subdomain, add an A record to the host's
   public IP with proxy **on** (orange cloud).

You'll paste the cert and key into sops on the host that needs it (see
below).

## Sops (one-time per instance)

Edit `.sops.yaml`:

```yaml
keys:
  - &admin_you  age1YOUR_LAPTOP_PUBLIC_KEY
  - &citadel    age1CITADEL_PUBLIC_KEY

creation_rules:
  - path_regex: secrets/citadel\.yaml$
    key_groups:
      - age:
          - *admin_you
          - *citadel
```

`&citadel` is the box's age recipient, derived from its SSH host key.
Two ways to get it:

- **After a bare install** — SSH in and compute:
  ```sh
  ssh root@<host> cat /etc/ssh/ssh_host_ed25519_key.pub \
    | nix run nixpkgs#ssh-to-age
  ```
- **Before install** — `install-host` generates the SSH host key locally
  under `secrets/<host>/ssh/` and prints the derived recipient. Paste it
  into `.sops.yaml`, then re-run `install-host`.

## Provisioning a fresh host

```sh
install-host citadel
```

What happens:

1. Generates the initrd SSH host key at `secrets/citadel/initrd/`.
2. If the config declares any sops secrets:
   - Generates the main SSH host key at `secrets/citadel/ssh/`. Its
     public part is the box's age recipient — `install-host` prints it.
   - Verifies `.sops.yaml` includes that recipient. If missing, prints
     what to add and exits.
   - Runs `update-secrets` to prompt for any missing sops values.
3. Bundles both SSH keys via `--extra-files` and kexecs a NixOS installer
   over any live Linux (Hetzner rescue, a running Debian, cloud image).
4. Prompts you for the ZFS passphrase during install. Remember it — you'll
   type it on every boot.

On first boot the box already has its SSH host key, so sops-nix decrypts
the shipped secrets and every service comes up automatically.

Unlocking the ZFS pool on each boot (from your laptop):

```sh
ssh -p 2222 root@<host>
systemd-tty-ask-password-agent --query
```

## Deploying changes

```sh
deploy .#<name>
```

`deploy-rs` builds the closure, copies to the host, activates, and rolls
back on failure or health check timeout.

## Managing secrets later

Any time you enable a service or add a user that expects a sops secret:

```sh
update-secrets <host>
```

Reads `.#nixosConfigurations.<host>.config.sops.secrets`, checks what's
already in `secrets/<host>.yaml`, prompts only for missing keys.

To change a value:

```sh
sops secrets/<host>.yaml
# edit in $EDITOR, save
deploy .#<host>
```

## Troubleshooting

- **`deploy` fails building `sops-install-secrets` with 403 from
  `proxy.golang.org`.** castle wires `nix-community.cachix.org` as an
  extra substituter — accept the flake config (`--accept-flake-config`
  once, or add `accept-flake-config = true` to `~/.config/nix/nix.conf`).
- **Caddy won't start.** `journalctl -u caddy` — usually the sops
  secrets aren't group-readable, or the cert/key contents are wrong.
- **Forgejo user provisioning fails.** `journalctl -u forgejo-users-init`
  — usually the password is too weak (Forgejo requires ≥ 6 chars by
  default).

## Reference

- castle library: [github.com/haqops/castle](https://github.com/haqops/castle)
- deploy-rs: [github.com/serokell/deploy-rs](https://github.com/serokell/deploy-rs)
- sops-nix: [github.com/Mic92/sops-nix](https://github.com/Mic92/sops-nix)
