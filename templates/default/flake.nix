{
  description = "castle instance — private register of hosts";

  inputs = {
    castle.url = "github:haqops/castle";
    nixpkgs.follows = "castle/nixpkgs";
    deploy-rs.follows = "castle/deploy-rs";
    darwin.follows = "castle/darwin";
  };

  outputs = { self, castle, nixpkgs, deploy-rs, darwin, ... }: let
    systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system:
      f { inherit system; pkgs = nixpkgs.legacyPackages.${system}; });

    data = import ./hosts.nix castle;
  in {
    nixosConfigurations  = castle.lib.mkNixosConfigs  data;
    darwinConfigurations = castle.lib.mkDarwinConfigs data;

    deploy.nodes = castle.lib.mkDeploy self.nixosConfigurations;

    checks = builtins.mapAttrs
      (_: deployLib: deployLib.deployChecks self.deploy)
      deploy-rs.lib;

    devShells = forAllSystems ({ system, pkgs }: {
      default = pkgs.mkShellNoCC {
        packages = [
          (pkgs.writeShellScriptBin "install-host" ''
            exec ${castle}/install.sh "$@"
          '')
          (pkgs.writeShellScriptBin "update-secrets" ''
            exec ${castle}/update-secrets.sh "$@"
          '')
          # activate <host> — one command, right tool per platform.
          # NixOS host  → deploy-rs (build here, push, activate with rollback)
          # Darwin host → sudo darwin-rebuild switch --flake .#<host> (locally)
          (pkgs.writeShellScriptBin "activate" ''
            set -euo pipefail
            host="''${1:?usage: activate <host>}"
            if nix eval ".#nixosConfigurations.\"$host\"" --apply "_: true" >/dev/null 2>&1; then
              exec deploy ".#$host"
            elif nix eval ".#darwinConfigurations.\"$host\"" --apply "_: true" >/dev/null 2>&1; then
              exec sudo darwin-rebuild switch --flake ".#$host"
            else
              echo "!! unknown host: $host" >&2
              exit 1
            fi
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
          echo "  install-host <name>    provision a fresh NixOS box (keys, secrets, kexec)"
          echo "  update-secrets <name>  interactively fill missing sops secrets"
          echo "  activate <name>        deploy/activate <name> — right tool per platform"
        '';
      };
    });
  };
}
