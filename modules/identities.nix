{ config, lib, ... }: let
  humans           = config.castle.humans;
  agents           = config.castle.agents;
  all              = humans // agents;
  identitySubmodule = import ../lib/identitySubmodule.nix { inherit lib; };
in {
  options.castle = {
    humans = lib.mkOption {
      type    = lib.types.attrsOf identitySubmodule;
      default = {};
      description = ''
        People. Get service accounts and, on towers where they're listed
        in castle.tower.accounts, a local Unix account created manually
        on macOS (via Setup Assistant, so they get SecureToken and can
        unlock FileVault) or automatically on Linux.
      '';
    };

    agents = lib.mkOption {
      type    = lib.types.attrsOf identitySubmodule;
      default = {};
      description = ''
        Autonomous accounts. Get service accounts and, on towers where
        they're listed in castle.tower.accounts, a local Unix account
        that castle creates declaratively on every platform (dscl on
        macOS, users.users on Linux).
      '';
    };
  };

  config = {
    users.groups.castle-user-secrets = {};

    sops.secrets = lib.mapAttrs' (name: _: lib.nameValuePair
      "users/${name}/password"
      {
        group = "castle-user-secrets";
        mode  = "0440";
      }
    ) all;
  };
}
