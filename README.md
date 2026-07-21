# castle

Opinionated NixOS foundation for building small self-hosted infrastructures.

## What you get

- Encrypted ZFS root (aes-256-gcm + zstd), SSH unlock in initrd on port 2222
- DHCP via systemd-networkd, tuned for Hetzner Cloud VMs (bare metal / other
  clouds are supported via option toggles + your own disko/hardware-config)
- Reverse proxy (Caddy) with a Cloudflare Origin CA cert — no ACME, no
  renewals, 15-year validity
- Shared PostgreSQL + sops-nix for secrets, age identity derived from the
  host's SSH host key
- One declarative user registry (`castle.users`) that every service
  provisions accounts from
- One-shot provisioning: `install-host <name>` generates SSH host keys,
  populates missing sops secrets, kexecs a NixOS installer, and activates
  the box with services already running
- `deploy .#<name>` for post-install activation with automatic rollback

Available services today: **Forgejo** (git hosting + CI). Planned:
Discourse, Plane, Zulip. Towers (workstations for humans + agents) later.

## Getting started

Create your own castle instance — a private repo with your hosts, users,
and secrets:

```sh
mkdir my-castle && cd my-castle
nix flake init -t github:haqops/castle
```

Everything about running your castle — configuring hosts, adding users,
Cloudflare setup, provisioning secrets, install and deploy — lives in the
`README.md` that gets copied into your instance.

## Design tenets

- **Data-only host declarations.** Each host is a NixOS module in
  `hosts.nix`, tuned through `castle.*` options. Nothing per-host is
  hardcoded in the library.
- **Options with sensible defaults.** Every module toggles via
  `castle.<x>.enable`. Bare-metal boxes turn off `castle.hetzner.enable`
  and add their own disko + hardware imports.
- **One source of truth for users.** `castle.users.<name>` declares
  people once; every service provisions the same list.
- **No ACME.** Cloudflare Origin CA covers all subdomains for 15 years.
- **No forking.** Consume as a flake input; tune via options; add your
  own modules alongside.

## Flake outputs

- `nixosModules.default` — aggregator; imports every castle module +
  sops-nix. Opt-in via `castle.*.enable`.
- `nixosModules.{nix-defaults,hetzner-cloud,zfs,initrd-ssh,ssh,sops,users,caddy,postgres,services-forgejo}`
  — individual leaves.
- `diskoConfigs.zfs-single` — `/dev/sda`: `bios_boot` (1M) + `/boot`
  ext4 (1G) + `rpool` ZFS (aes-256-gcm + zstd) with datasets `root`,
  `nix`, `home`, `reserved`.
- `lib.mkHost { name, cfg }` — thin wrapper around
  `nixpkgs.lib.nixosSystem`. Auto-imports `nixosModules.default` and the
  chosen `diskoConfigs.<disk>` (default `zfs-single`).
- `lib.mkDeploy nixosConfigurations` — turns each `nixosConfiguration`
  into a `deploy.nodes.<name>` entry for deploy-rs.
- `apps.<system>.install` — wraps `nixos-anywhere`.
- `templates.default` — the skeleton copied by `nix flake init`.

## Repo layout

```
castle/
├── flake.nix
├── modules/
│   ├── default.nix              # aggregator + castle.host options
│   ├── nix-defaults.nix
│   ├── hetzner-cloud.nix
│   ├── zfs.nix
│   ├── initrd-ssh.nix
│   ├── ssh.nix
│   ├── sops.nix
│   ├── users.nix
│   ├── caddy.nix
│   ├── postgres.nix
│   └── services/
│       └── forgejo.nix
├── disko/
│   └── zfs-single.nix
├── lib/
│   ├── mkHost.nix
│   └── mkDeploy.nix
├── install.sh                   # runs as `install-host` in the devShell
├── update-secrets.sh            # runs as `update-secrets` in the devShell
└── templates/default/           # copied by `nix flake init`
```

## Options quick reference

| option                            | default        |
|-----------------------------------|----------------|
| `castle.host.ipv4`                | *(required)*   |
| `castle.host.sshKeys`             | `[]`           |
| `castle.hetzner.enable`           | `true`         |
| `castle.zfs.enable`               | `true`         |
| `castle.zfs.autoScrub`            | `true`         |
| `castle.initrdSsh.enable`         | `true`         |
| `castle.initrdSsh.port`           | `2222`         |
| `castle.ssh.enable`               | `true`         |
| `castle.ssh.port`                 | `22`           |
| `castle.nixDefaults.enable`       | `true`         |
| `castle.nixDefaults.timeZone`     | `"UTC"`        |
| `castle.users.<name>.email`       | *(required)*   |
| `castle.users.<name>.admin`       | `false`        |
| `castle.caddy.enable`             | `false`, auto  |
| `castle.postgres.enable`          | `false`, auto  |
| `castle.services.forgejo.enable`  | `false`        |
| `castle.services.forgejo.domain`  | *(required)*   |
