{ lib, ... }: {
  imports = [
    ./nix-defaults.nix
    ./hetzner-cloud.nix
    ./zfs.nix
    ./initrd-ssh.nix
    ./ssh.nix
    ./sops.nix
    ./identities.nix
    ./caddy.nix
    ./postgres.nix
    ./tower.nix
    ./services/forgejo.nix
    ./services/discourse.nix
  ];

  options.castle.host = {
    ipv4 = lib.mkOption {
      type = lib.types.str;
      description = "Public IPv4 address of the host. Consumed by install/ops tooling, not by NixOS itself (DHCP handles addressing).";
    };
    sshKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "SSH public keys authorized for root on this host (and, by default, in initrd).";
    };
    arch = lib.mkOption {
      type = lib.types.str;
      default = "x86_64-linux";
      description = ''
        Nix system triple for this host. mkNixosConfigs handles
        `x86_64-linux` and `aarch64-linux`; mkDarwinConfigs handles
        `x86_64-darwin` and `aarch64-darwin`. Determines which builder
        picks up the host.
      '';
    };
  };
}
