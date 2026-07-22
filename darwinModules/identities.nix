{ lib, ... }: let
  identitySubmodule = import ../lib/identitySubmodule.nix { inherit lib; };
in {
  options.castle = {
    humans = lib.mkOption {
      type    = lib.types.attrsOf identitySubmodule;
      default = {};
      description = ''
        People. On a darwin tower they're assumed to already exist —
        created via macOS Setup Assistant so they have SecureToken and
        can unlock FileVault. castle only applies home-manager config
        for them, doesn't touch the account itself.
      '';
    };

    agents = lib.mkOption {
      type    = lib.types.attrsOf identitySubmodule;
      default = {};
      description = ''
        Autonomous accounts. Created declaratively via nix-darwin's
        users.users.<name> (dscl). Require an explicit `uid` — nix-darwin
        does not auto-assign.
      '';
    };
  };
}
