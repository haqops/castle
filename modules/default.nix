{ lib, ... }: {
  imports = [
    ./nix-defaults.nix
    ./hetzner-cloud.nix
    ./zfs.nix
    ./initrd-ssh.nix
    ./ssh.nix
    ./sops.nix
    ./users.nix
    ./caddy.nix
    ./postgres.nix
    ./services/forgejo.nix
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
  };
}
