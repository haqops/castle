{
  description = "castle — Agent Castle: NixOS + nix-darwin foundation for humans and their agents";

  nixConfig = {
    extra-substituters = [ "https://nix-community.cachix.org" ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, sops-nix, deploy-rs, darwin, home-manager, ... }: {
    nixosModules = {
      default = {
        imports = [
          sops-nix.nixosModules.sops
          ./modules
        ];
      };
      nix-defaults    = ./modules/nix-defaults.nix;
      hetzner-cloud   = ./modules/hetzner-cloud.nix;
      zfs             = ./modules/zfs.nix;
      initrd-ssh      = ./modules/initrd-ssh.nix;
      ssh             = ./modules/ssh.nix;
      sops            = ./modules/sops.nix;
      identities      = ./modules/identities.nix;
      caddy           = ./modules/caddy.nix;
      postgres        = ./modules/postgres.nix;
      tower           = ./modules/tower.nix;
      services-forgejo = ./modules/services/forgejo.nix;
      services-discourse = ./modules/services/discourse.nix;
    };

    darwinModules = {
      default    = ./darwinModules;
      identities = ./darwinModules/identities.nix;
      tower      = ./darwinModules/tower.nix;
    };

    diskoConfigs = {
      zfs-single = ./disko/zfs-single.nix;
    };

    lib = {
      mkNixosConfigs  = import ./lib/mkNixosConfigs.nix  { inherit nixpkgs disko self; };
      mkDarwinConfigs = import ./lib/mkDarwinConfigs.nix { inherit nixpkgs darwin home-manager self; };
      mkDeploy        = import ./lib/mkDeploy.nix        { inherit deploy-rs; };
    };

    templates.default = {
      path = ./templates/default;
      description = "castle instance — private register of hosts";
    };

    apps = builtins.listToAttrs (map (system: {
      name = system;
      value.install = {
        type = "app";
        program = toString (self + "/install.sh");
      };
    }) [ "x86_64-linux" "aarch64-linux" ]);
  };
}
