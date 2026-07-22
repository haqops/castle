{
  description = "castle — NixOS foundation for encrypted Hetzner Cloud VMs";

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
  };

  outputs = { self, nixpkgs, disko, sops-nix, deploy-rs, ... }: {
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
      caddy           = ./modules/caddy.nix;
      postgres        = ./modules/postgres.nix;
      services-forgejo = ./modules/services/forgejo.nix;
      services-discourse = ./modules/services/discourse.nix;
    };

    diskoConfigs = {
      zfs-single = ./disko/zfs-single.nix;
    };

    lib = {
      mkHost   = import ./lib/mkHost.nix   { inherit nixpkgs disko self; };
      mkDeploy = import ./lib/mkDeploy.nix { inherit deploy-rs; };
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
