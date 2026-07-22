# Reference

Technical reference for the castle library itself. For operating your
own castle, see the README that `nix flake init -t github:haqops/castle`
copies into your instance.

## Flake outputs

- `nixosModules.default` — aggregator; imports every NixOS castle module
  plus sops-nix. Everything is opt-in via `castle.*.enable`.
- `nixosModules.{nix-defaults,hetzner-cloud,zfs,initrd-ssh,ssh,sops,identities,caddy,postgres,tower,services-forgejo,services-discourse}`
  — individual leaves, useful if you want to consume one piece without
  the aggregator.
- `darwinModules.default` — nix-darwin aggregator for Mac towers.
- `darwinModules.{identities,tower}` — individual leaves for darwin.
- `diskoConfigs.zfs-single` — `/dev/sda` layout: `bios_boot` (1M) +
  `/boot` ext4 (1G) + `rpool` ZFS (`aes-256-gcm` + `zstd`) with datasets
  `root`, `nix`, `home`, `reserved`.
- `lib.mkNixosConfigs { humans ? {}, agents ? {}, hosts }` — takes the
  payload returned by an instance's `hosts.nix` and yields
  `nixosConfigurations`. Auto-imports `nixosModules.default` and the
  chosen `diskoConfigs.<disk>` (default `zfs-single`) into each host,
  and injects `castle.humans = humans; castle.agents = agents` so the
  global registries propagate everywhere. Skips hosts whose
  `castle.host.arch` is darwin (those go through the darwin path).
- `lib.mkDarwinConfigs { humans ? {}, agents ? {}, hosts }` — same
  payload, produces `darwinConfigurations`. Pulls in home-manager and
  the darwin aggregator. Only picks up hosts whose `castle.host.arch`
  is `x86_64-darwin` or `aarch64-darwin`.
- `lib.mkDeploy nixosConfigurations` — turns each `nixosConfiguration`
  into a `deploy.nodes.<name>` entry for deploy-rs. Darwin hosts are
  activated with `darwin-rebuild switch --flake .#<name>` for now;
  deploy-rs integration for darwin is deferred.
- `apps.<system>.install` — wraps `nixos-anywhere` and pre-flight secret
  handling.
- `templates.default` — the skeleton copied by `nix flake init`.

## Repo layout

```
castle/
├── flake.nix
├── darwinModules/
│   ├── default.nix
│   ├── identities.nix
│   └── tower.nix
├── modules/
│   ├── default.nix              # aggregator + castle.host options
│   ├── nix-defaults.nix
│   ├── hetzner-cloud.nix
│   ├── zfs.nix
│   ├── initrd-ssh.nix
│   ├── ssh.nix
│   ├── sops.nix
│   ├── identities.nix
│   ├── caddy.nix
│   ├── postgres.nix
│   ├── tower.nix
│   └── services/
│       ├── forgejo.nix
│       └── discourse.nix
├── disko/
│   └── zfs-single.nix
├── lib/
│   ├── identitySubmodule.nix
│   ├── mkNixosConfigs.nix
│   ├── mkDarwinConfigs.nix
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
| `castle.humans.<name>.email`          | *(required)*   |
| `castle.humans.<name>.admin`          | `false`        |
| `castle.humans.<name>.uid`            | `null`         |
| `castle.humans.<name>.sshKeys`        | `[]`           |
| `castle.humans.<name>.shell`          | `null`         |
| `castle.humans.<name>.editor`         | `null`         |
| `castle.humans.<name>.tools`          | `[]`           |
| `castle.humans.<name>.extraPackages`  | `null`         |
| `castle.agents.<name>.*`              | same as humans |
| `castle.host.arch`                    | `"x86_64-linux"` |
| `castle.tower.enable`                 | `false`        |
| `castle.tower.accounts`               | `[]`           |
| `castle.tower.defaultTools`           | curated list   |
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
