{
  description = "castle instance — private register of hosts";

  inputs = {
    castle.url = "github:haqops/castle";
    nixpkgs.follows = "castle/nixpkgs";
  };

  outputs = { self, castle, nixpkgs, ... }: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    hosts = import ./hosts.nix castle;
  in {
    nixosConfigurations = builtins.mapAttrs
      (name: cfg: castle.lib.mkHost { inherit name cfg; })
      hosts;

    devShells.${system}.default = pkgs.mkShellNoCC {
      packages = [
        (pkgs.writeShellScriptBin "install-host" ''
          exec ${castle}/install.sh "$@"
        '')
      ];
      shellHook = ''
        echo "castle instance. commands:"
        echo "  install-host <name>   bootstrap NixOS on <name> (from hosts.nix)"
      '';
    };
  };
}
