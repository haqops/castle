# Build darwinConfigurations from a `{ humans, agents, hosts }` payload,
# filtering hosts by castle.host.arch (darwin* only).
{ nixpkgs, darwin, home-manager, self }:
{ humans ? {}, agents ? {}, hosts }:
let
  isDarwin = cfg:
    let a = cfg.castle.host.arch or "x86_64-linux";
    in a == "x86_64-darwin" || a == "aarch64-darwin";

  mkOne = name: cfg: darwin.lib.darwinSystem {
    system = cfg.castle.host.arch;
    modules = [
      home-manager.darwinModules.home-manager
      self.darwinModules.default
      ({ ... }: {
        networking.hostName = name;
        system.stateVersion = 5;
      })
      { castle.humans = humans; castle.agents = agents; }
      cfg
    ];
  };
in
builtins.mapAttrs mkOne (nixpkgs.lib.filterAttrs (_: isDarwin) hosts)
