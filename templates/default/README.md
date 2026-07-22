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
accounts (Forgejo, Discourse, and anything you add later) provisions
the same list.

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

## Adding a service: Discourse

```nix
citadel = {
  # ...host stuff, castle.users...
  sops.defaultSopsFile = ./secrets/citadel.yaml;

  castle.services.discourse = {
    enable = true;
    domain = "discourse.example.com";
    s3 = {
      endpoint      = "https://<account_id>.r2.cloudflarestorage.com";
      uploadsBucket = "<bucket-for-uploads>";
      backupsBucket = "<bucket-for-backups>";
      region        = "auto";
    };
  };
};
```

Turning on Discourse auto-enables Caddy and PostgreSQL. It is private by
default: no guest reads, invite-only signup, admin-approved accounts.
The first admin — the `castle.users` entry with `admin = true` — is
created automatically; log in with the password from
`users/<name>/password` in sops.

Discourse needs S3-compatible storage for uploads and backups. Castle
assumes Cloudflare R2 (endpoint pattern above); anything with an S3 API
works.

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

You need a `.sops.yaml` with one entry — your own age recipient (the
laptop / workstation from which you'll run `deploy` and edit secrets):

```yaml
keys:
  - &admin_you  age1YOUR_LAPTOP_PUBLIC_KEY

creation_rules: []
```

No age key yet? Generate one:

```sh
mkdir -p ~/.config/sops/age
nix shell nixpkgs#age -c age-keygen -o ~/.config/sops/age/keys.txt
grep 'public key' ~/.config/sops/age/keys.txt
```

`install-host` handles the per-host part: it generates each box's SSH
host key locally, derives the box's age recipient, appends an anchor
plus a matching creation_rule to `.sops.yaml`, and re-encrypts existing
secrets for the new recipient set. You never edit host keys into
`.sops.yaml` by hand.

## Provisioning a fresh host

```sh
install-host citadel
```

What happens:

1. Generates the initrd SSH host key at `secrets/citadel/initrd/`.
2. If the config declares any sops secrets:
   - Generates the main SSH host key at `secrets/citadel/ssh/`. Its
     public part is the box's age recipient.
   - Adds an anchor and a per-host creation_rule to `.sops.yaml` (or
     re-encrypts existing secrets under the new recipient set if the
     host is being reinstalled).
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

The same reminder is printed as an initrd motd on every SSH login into
port 2222, so you don't have to remember the command.

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
- **Discourse loads but assets 404.** Check that `serve_static_assets`
  is `true` in `/var/lib/discourse/config/discourse.conf` — required
  because castle disables Discourse's built-in nginx.
- **Discourse admin login fails after install.** The password lives in
  sops at `users/<admin>/password`; it must be ≥ 10 chars for
  Discourse's admin policy.

## Reference

- castle library: [github.com/haqops/castle](https://github.com/haqops/castle)
- deploy-rs: [github.com/serokell/deploy-rs](https://github.com/serokell/deploy-rs)
- sops-nix: [github.com/Mic92/sops-nix](https://github.com/Mic92/sops-nix)
