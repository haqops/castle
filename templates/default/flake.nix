{
  description = "castle instance — private register of hosts";

  inputs = {
    castle.url = "github:haqops/castle";
    nixpkgs.follows = "castle/nixpkgs";
    deploy-rs.follows = "castle/deploy-rs";
    darwin.follows = "castle/darwin";
  };

  outputs = { self, castle, nixpkgs, deploy-rs, darwin, ... }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    data = import ./hosts.nix castle;
  in {
    nixosConfigurations  = castle.lib.mkNixosConfigs  data;
    darwinConfigurations = castle.lib.mkDarwinConfigs data;

    deploy.nodes = castle.lib.mkDeploy self.nixosConfigurations;

    checks = builtins.mapAttrs
      (_: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib;

    devShells.${system}.default = pkgs.mkShellNoCC {
      packages = [
        (pkgs.writeShellScriptBin "install-host" ''
          exec ${castle}/install.sh "$@"
        '')
        (pkgs.writeShellScriptBin "update-secrets" ''
          exec ${castle}/update-secrets.sh "$@"
        '')
        deploy-rs.packages.${system}.default
        pkgs.sops
        pkgs.age
        pkgs.ssh-to-age
        pkgs.jq
        pkgs.openssl
      ];
      shellHook = ''
        export SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
        echo "castle instance. commands:"
        echo "  install-host <name>    provision <name> from scratch (keys, secrets, NixOS)"
        echo "  update-secrets <name>  interactively fill missing sops secrets for <name>"
        echo "  deploy .#<name>        activate current NixOS config on <name>"
        echo "  darwin-rebuild switch --flake .#<studio>   activate current darwin config"
      '';
    };
  };
}
