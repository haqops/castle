{ lib, ... }: {
  imports = [
    ./identities.nix
    ./tower.nix
    ./services/rapid-mlx.nix
  ];

  options.castle.host = {
    ipv4 = lib.mkOption {
      type    = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Public IPv4, if any. Optional on darwin towers — a Mac usually
        lives on a LAN and gets driven from itself. Set it if you want
        remote deploy tooling to reach the box.
      '';
    };
    sshKeys = lib.mkOption {
      type    = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        SSH public keys authorized for the current login user (typically
        the person driving `darwin-rebuild`). Optional.
      '';
    };
    arch = lib.mkOption {
      type = lib.types.enum [ "x86_64-darwin" "aarch64-darwin" ];
      description = ''
        Nix system triple. Required on darwin hosts — no default so it
        can't accidentally be picked up by mkNixosConfigs.
      '';
    };
  };
}
