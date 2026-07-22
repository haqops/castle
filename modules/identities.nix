{ config, lib, ... }: let
  humans = config.castle.humans;
  agents = config.castle.agents;
  all    = humans // agents;

  identitySubmodule = lib.types.submodule {
    options = {
      email = lib.mkOption {
        type = lib.types.str;
        description = "Email address; used as identity in services and git.";
      };
      admin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Grant admin-level rights on every service that has such a concept
          (site admin in Forgejo, Discourse admin, etc.) and wheel/sudo on
          towers where this identity has a local account.
        '';
      };
      sshKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          SSH public keys added to authorized_keys on every tower that
          provisions this identity.
        '';
      };
      shell = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "bash" "zsh" "fish" ]);
        default = null;
        description = ''
          Interactive shell on towers. If null, the account is treated as
          headless. Agents may have a shell too — that doesn't make them
          humans; the bucket does.
        '';
      };
      editor = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum [ "nvim" "vim" "emacs" "helix" "nano" ]);
        default = null;
        description = "Editor package to install on towers.";
      };
      tools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = ''
          Extra packages installed on towers, by nixpkgs attribute name.
          Added on top of castle.tower.defaultTools.
        '';
      };
      extraPackages = lib.mkOption {
        type = lib.types.nullOr (lib.types.functionTo (lib.types.listOf lib.types.package));
        default = null;
        description = ''
          Escape hatch for packages that aren't a plain pkgs.<name>:
          overlays, custom flake inputs, etc.
        '';
      };
    };
  };
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
