{ deploy-rs }:
nixosConfigurations:
builtins.mapAttrs (name: nixosConfig: {
  hostname = nixosConfig.config.castle.host.ipv4;
  profiles.system = {
    user = "root";
    path = deploy-rs.lib.${nixosConfig.pkgs.stdenv.hostPlatform.system}.activate.nixos
      nixosConfig;
  };
}) nixosConfigurations
