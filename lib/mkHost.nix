{ nixpkgs, disko, self }:
{ name, cfg }:
let
  diskName  = cfg.disk or "zfs-single";
  nixosCfg  = builtins.removeAttrs cfg [ "disk" ];
  diskExtra = if diskName == null then [] else [ self.diskoConfigs.${diskName} ];
in
nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";
  modules = [
    disko.nixosModules.disko
    self.nixosModules.default
    ({ config, ... }: {
      networking.hostName = name;
      networking.hostId   = builtins.substring 0 8 (builtins.hashString "md5" name);
      users.users.root.openssh.authorizedKeys.keys = config.castle.host.sshKeys;
      system.stateVersion = "25.05";
    })
    nixosCfg
  ] ++ diskExtra;
}
