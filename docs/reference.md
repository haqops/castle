# Reference

Technical reference for the castle library itself. For operating your
own castle, see the README that `nix flake init -t github:haqops/castle`
copies into your instance.

## Flake outputs

- `nixosModules.default` — aggregator; imports every castle module plus
  sops-nix. Everything is opt-in via `castle.*.enable`.
- `nixosModules.{nix-defaults,hetzner-cloud,zfs,initrd-ssh,ssh,sops,caddy,postgres,services-forgejo,services-discourse}`
  — individual leaves, useful if you want to consume one piece without
  the aggregator.
- `diskoConfigs.zfs-single` — `/dev/sda` layout: `bios_boot` (1M) +
  `/boot` ext4 (1G) + `rpool` ZFS (`aes-256-gcm` + `zstd`) with datasets
  `root`, `nix`, `home`, `reserved`.
- `lib.mkHost { name, cfg }` — thin wrapper around
  `nixpkgs.lib.nixosSystem`. Auto-imports `nixosModules.default` and the
  chosen `diskoConfigs.<disk>` (default `zfs-single`).
- `lib.mkDeploy nixosConfigurations` — turns each `nixosConfiguration`
  into a `deploy.nodes.<name>` entry for deploy-rs.
- `apps.<system>.install` — wraps `nixos-anywhere` and pre-flight secret
  handling.
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
│       ├── forgejo.nix
│       └── discourse.nix
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

| option                                | default        |
|---------------------------------------|----------------|
| `castle.host.ipv4`                    | *(required)*   |
| `castle.host.sshKeys`                 | `[]`           |
| `castle.hetzner.enable`               | `true`         |
| `castle.zfs.enable`                   | `true`         |
| `castle.zfs.autoScrub`                | `true`         |
| `castle.initrdSsh.enable`             | `true`         |
| `castle.initrdSsh.port`               | `2222`         |
| `castle.ssh.enable`                   | `true`         |
| `castle.ssh.port`                     | `22`           |
| `castle.nixDefaults.enable`           | `true`         |
| `castle.nixDefaults.timeZone`         | `"UTC"`        |
| `castle.users.<name>.email`           | *(required)*   |
| `castle.users.<name>.admin`           | `false`        |
| `castle.caddy.enable`                 | `false`, auto  |
| `castle.postgres.enable`              | `false`, auto  |
| `castle.postgres.package`             | `postgresql_15`|
| `castle.services.forgejo.enable`      | `false`        |
| `castle.services.forgejo.domain`      | *(required)*   |
| `castle.services.discourse.enable`    | `false`        |
| `castle.services.discourse.domain`    | *(required)*   |
| `castle.services.discourse.smtp.host` | `null`         |
| `castle.services.discourse.s3.*`      | *(required)*   |

Options marked *auto* enable themselves when a service that needs them
turns on. You never set them by hand.
