{ config, lib, ... }: let
  cfg = config.castle.users;
in {
  options.castle.users = lib.mkOption {
    default = {};
    description = ''
      People (and later machine accounts) who should have accounts across
      castle services. Each service module reads this attrset and creates
      matching accounts. One password per user, stored at sops path
      `users/<name>/password`, shared across every service the user is
      provisioned into.
    '';
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        email = lib.mkOption {
          type = lib.types.str;
          description = "Email address for the user.";
        };
        admin = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Grant admin-level rights on every service that has such a
            concept (site admin in Forgejo; wheel/sudo on Tower OS users
            once tower lands; etc).
          '';
        };
      };
    });
  };

  config = {
    users.groups.castle-user-secrets = {};

    sops.secrets = lib.mapAttrs' (name: _: lib.nameValuePair
      "users/${name}/password"
      {
        group = "castle-user-secrets";
        mode = "0440";
      }
    ) cfg;
  };
}
