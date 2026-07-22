# Build the nixosConfigurations attrset from a `{ humans, agents, hosts }`
# payload. Filters out hosts whose `castle.host.arch` is darwin — those go
# through `mkDarwinConfigs`.
{ nixpkgs, disko, self }:
{ humans ? {}, agents ? {}, hosts }:
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
        # Inject the global identity registries into every host.
        { castle.humans = humans; castle.agents = agents; }
        nixosCfg
      ] ++ diskExtra;
    };
in
builtins.mapAttrs mkOne (nixpkgs.lib.filterAttrs (_: isLinux) hosts)
