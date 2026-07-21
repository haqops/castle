{
  description = "castle — NixOS foundation for encrypted Hetzner Cloud VMs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, disko, ... }: {
    nixosModules = {
      default       = ./modules;                    # aggregator: all castle modules, opt-in via castle.*.enable
      nix-defaults  = ./modules/nix-defaults.nix;
      hetzner-cloud = ./modules/hetzner-cloud.nix;
      zfs           = ./modules/zfs.nix;
      initrd-ssh    = ./modules/initrd-ssh.nix;
      ssh           = ./modules/ssh.nix;
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
