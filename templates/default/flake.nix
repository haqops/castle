{
  description = "castle instance — private register of hosts";

  inputs = {
    castle.url = "github:haqops/castle";
  };

  outputs = { self, castle, ... }: let
    hosts = import ./hosts.nix castle;
  in {
    nixosConfigurations = builtins.mapAttrs
      (name: cfg: castle.lib.mkHost { inherit name cfg; })
      hosts;
  };
}
