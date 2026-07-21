{
  description = "castle instance — private register of hosts";

  inputs = {
    castle.url = "github:haqops/castle";
    nixpkgs.follows = "castle/nixpkgs";
    deploy-rs.follows = "castle/deploy-rs";
  };

  outputs = { self, castle, nixpkgs, deploy-rs, ... }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    hosts = import ./hosts.nix castle;
  in {
    nixosConfigurations = builtins.mapAttrs
      (name: cfg: castle.lib.mkHost { inherit name cfg; })
      hosts;

    deploy.nodes = castle.lib.mkDeploy self.nixosConfigurations;

    checks = builtins.mapAttrs
      (_: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib;

    devShells.${system}.default = pkgs.mkShellNoCC {
      packages = [
        (pkgs.writeShellScriptBin "install-host" ''
          exec ${castle}/install.sh "$@"
        '')
        deploy-rs.packages.${system}.default
      ];
      shellHook = ''
        echo "castle instance. commands:"
        echo "  install-host <name>   bootstrap NixOS on <name> (fresh box, no secrets)"
        echo "  deploy .#<name>       activate current config on <name> via deploy-rs"
      '';
    };
  };
}
