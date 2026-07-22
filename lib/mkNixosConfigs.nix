# Build the nixosConfigurations attrset from a `{ users, hosts }` payload.
#
# Filters out any host that declares a non-linux `castle.host.arch` — those
# are dispatched to nix-darwin via `mkDarwinConfigs`.
{ nixpkgs, disko, self }:
{ users ? {}, hosts }:
let
  isLinux = cfg:
    let a = cfg.castle.host.arch or "x86_64-linux";
    in a == "x86_64-linux" || a == "aarch64-linux";

  mkOne = name: cfg:
    let
      diskName  = cfg.disk or "zfs-single";
      nixosCfg  = builtins.removeAttrs cfg [ "disk" ];
      diskExtra = if diskName == null then [] else [ self.diskoConfigs.${diskName} ];
    in nixpkgs.lib.nixosSystem {
      system = cfg.castle.host.arch or "x86_64-linux";
      modules = [
        disko.nixosModules.disko
        self.nixosModules.default
        ({ config, ... }: {
          networking.hostName = name;
          networking.hostId   = builtins.substring 0 8 (builtins.hashString "md5" name);
          users.users.root.openssh.authorizedKeys.keys = config.castle.host.sshKeys;
          system.stateVersion = "25.05";
        })
        # Inject the global user registry into every host.
        { castle.users = users; }
        nixosCfg
      ] ++ diskExtra;
    };
in
builtins.mapAttrs mkOne (nixpkgs.lib.filterAttrs (_: isLinux) hosts)
