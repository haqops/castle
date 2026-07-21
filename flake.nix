{
  description = "castle — NixOS foundation for encrypted Hetzner Cloud VMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, sops-nix, ... }: {
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
    };

    diskoConfigs = {
      zfs-single = ./disko/zfs-single.nix;
    };

    lib = {
      mkHost = import ./lib/mkHost.nix { inherit nixpkgs disko self; };
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
