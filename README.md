# castle

Opinionated NixOS foundation for encrypted Hetzner Cloud VMs. Bring up a fresh
box with:

- Encrypted ZFS root (aes-256-gcm + zstd, BIOS/GRUB)
- SSH-unlock in initrd on port 2222 (systemd-initrd + DHCP)
- DHCP through systemd-networkd
- Options-based composition — turn things off, tune ports, swap disko/hardware
  per host without forking

## Quickstart

```sh
mkdir my-castle && cd my-castle
nix flake init -t github:haqops/castle
```

You now have `flake.nix`, `hosts.nix` (with commented examples), `.envrc`
(direnv auto-activation), and a `.gitignore` covering `secrets/` and build
artifacts. Fill in a host:

```nix
# hosts.nix
castle: {
  citadel = {
    castle.host.ipv4    = "203.0.113.42";
    castle.host.sshKeys = [ "ssh-ed25519 AAAA... you@laptop" ];
  };
}
```

That's it — everything else defaults sensibly for a Hetzner Cloud VM. Enter
the devShell (or let direnv do it on `cd`) and install:

```sh
nix develop      # or: direnv allow, then just cd back in
install-host citadel
```

`nixos-anywhere` kexecs a NixOS installer over any live Linux (Hetzner rescue,
a running Debian, etc.). On first run for a host it generates an initrd host
key into `secrets/<host>/` (gitignored), then prompts for the ZFS passphrase.

On every boot the box waits in initrd for the passphrase. Unlock:

```sh
ssh -p 2222 root@<ip>
systemd-tty-ask-password-agent --query
```

Then boot continues, `sshd` on port 22 comes up.

## `hosts.nix` shape

`hosts.nix` is a function taking `castle` and returning `{ <hostname> = <cfg>; }`.
Each `cfg` is a NixOS module — set castle options, add extra imports if needed.

```nix
castle: {
  # Typical Hetzner Cloud VM — everything is defaults.
  citadel = {
    castle.host.ipv4    = "203.0.113.42";
    castle.host.sshKeys = [ "ssh-ed25519 AAAA... you@laptop" ];
  };

  # Tuning some options.
  tuned = {
    castle.host.ipv4       = "203.0.113.43";
    castle.host.sshKeys    = [ "ssh-ed25519 AAAA..." ];
    castle.initrdSsh.port  = 22222;
    castle.zfs.autoScrub   = false;
  };

  # Bare metal / non-Hetzner: bring your own hardware-config and disko.
  bastion = {
    disk = null;                     # opt out of the built-in disko
    imports = [
      ./hardware/bastion.nix
      ./disko/bastion.nix
    ];
    castle.host.ipv4      = "10.0.0.5";
    castle.host.sshKeys   = [ "ssh-ed25519 AAAA..." ];
    castle.hetzner.enable = false;
  };
}
```

The one non-NixOS-module field is `disk`, read by `mkHost`:

- `disk = "zfs-single"` (default) — auto-imports `castle.diskoConfigs.zfs-single`
- `disk = null` — skip auto-disko; provide your own via `imports`

Everything else is standard NixOS module syntax — `imports`, `castle.*` options,
any other NixOS options you want to set.

## Options

All castle-provided modules default to enabled for a Hetzner Cloud VM. Turn
them off individually.

| option                        | default        | notes                                       |
|-------------------------------|----------------|---------------------------------------------|
| `castle.host.ipv4`            | *(required)*   | consumed by `install.sh`, not by NixOS      |
| `castle.host.sshKeys`         | `[]`           | root's `authorized_keys` + initrd default   |
| `castle.hetzner.enable`       | `true`         | DHCP via networkd, virtio, serial console   |
| `castle.zfs.enable`           | `true`         | ZFS runtime, `requestEncryptionCredentials` |
| `castle.zfs.autoScrub`        | `true`         | weekly scrub                                |
| `castle.initrdSsh.enable`     | `true`         | systemd-initrd + sshd for unlock            |
| `castle.initrdSsh.port`       | `2222`         |                                             |
| `castle.initrdSsh.hostKeyPath`| `/etc/secrets/initrd/ssh_host_ed25519_key` | provisioned via `--extra-files`     |
| `castle.initrdSsh.authorizedKeys` | `castle.host.sshKeys` |                                     |
| `castle.ssh.enable`           | `true`         | openssh on the main system                  |
| `castle.ssh.port`             | `22`           |                                             |
| `castle.nixDefaults.enable`   | `true`         | flakes, GC, TZ, locale, base toolbox        |
| `castle.nixDefaults.timeZone` | `"UTC"`        |                                             |
| `castle.nixDefaults.extraPackages` | `[]`      |                                             |

## Flake outputs

- `nixosModules.default` — aggregator, imports everything; opt-in via `castle.*.enable`.
- `nixosModules.{nix-defaults,hetzner-cloud,zfs,initrd-ssh,ssh}` — individual leaves.
- `diskoConfigs.zfs-single` — `/dev/sda`: `bios_boot` (1M) + `/boot` ext4 (1G) + `rpool` ZFS (aes-256-gcm + zstd); datasets `root`, `nix`, `home`, `reserved`.
- `lib.mkHost { name, cfg }` — thin wrapper around `nixpkgs.lib.nixosSystem`. Auto-imports `nixosModules.default` and the chosen `diskoConfigs.<disk>`. Sets hostname, hostId (derived from name), root's authorized keys from `config.castle.host.sshKeys`.
- `apps.<system>.install` — wraps `nixos-anywhere`, generates initrd host key on first run.
- `templates.default` — the skeleton copied by `nix flake init`.

## Local development

If you're hacking on castle alongside your instance, override the input:

```sh
nix flake update --override-input castle path:/path/to/castle
# or in your instance's flake.nix:
#   castle.url = "path:/path/to/castle";
```
