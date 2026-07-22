# Shared submodule for castle.humans.<name> and castle.agents.<name>.
# Same options on both platforms; NixOS/darwin modules that use it decide
# what side effects to apply per platform.
{ lib }:
lib.types.submodule {
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
    uid = lib.mkOption {
      type = lib.types.nullOr lib.types.int;
      default = null;
      description = ''
        Unix UID. Required for identities that castle provisions
        declaratively on a darwin tower (nix-darwin does not auto-assign).
        Ignored on Linux — NixOS picks a UID from its pool.
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
}
