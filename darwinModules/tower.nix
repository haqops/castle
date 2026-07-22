{ config, lib, pkgs, ... }: let
  cfg     = config.castle.tower;
  humans  = config.castle.humans;
  agents  = config.castle.agents;
  all     = humans // agents;

  managedAccts    = lib.filter (n: builtins.hasAttr n all)    cfg.accounts;
  managedHumans   = lib.filter (n: builtins.hasAttr n humans) cfg.accounts;
  managedAgents   = lib.filter (n: builtins.hasAttr n agents) cfg.accounts;

  shellPkgs = {
    zsh  = pkgs.zsh;
    bash = pkgs.bashInteractive;
    fish = pkgs.fish;
  };

  editorPkgs = {
    nvim  = pkgs.neovim;
    vim   = pkgs.vim;
    emacs = pkgs.emacs;
    helix = pkgs.helix;
    nano  = pkgs.nano;
  };

  shellFor  = u: if u.shell  != null then shellPkgs.${u.shell}   else pkgs.bashInteractive;
  editorFor = u: if u.editor != null then [ editorPkgs.${u.editor} ] else [];

  packagesFor = u: pkgs:
    map (n: pkgs.${n}) (cfg.defaultTools ++ u.tools)
    ++ editorFor u
    ++ (if u.extraPackages != null then u.extraPackages pkgs else []);

  # home-manager config produced for a given identity.
  # We install packages and nothing else — dotfiles stay whatever the user
  # already has. programs.<shell>.enable would rewrite ~/.zshrc etc, which
  # is exactly what a pre-existing macOS user doesn't want.
  homeCfgFor = _name: u: { lib, ... }: {
    home.stateVersion  = "25.05";
    home.username      = _name;
    home.homeDirectory = lib.mkForce "/Users/${_name}";
    home.packages      = packagesFor u pkgs;
  };
in {
  options.castle.tower = {
    enable = lib.mkEnableOption "castle tower on darwin (workstation for humans and their agents)";

    accounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Names from castle.humans and castle.agents to manage on this
        tower. Humans must exist in macOS already (Setup Assistant);
        castle just applies their home-manager config. Agents are
        created declaratively via nix-darwin.
      '';
    };

    defaultTools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "git" "gh" "direnv"
        "ripgrep" "fd" "bat" "eza"
        "jq" "yq"
        "less" "tmux"
        "curl" "wget"
      ];
      description = ''
        Packages every managed identity gets, resolved by name against
        nixpkgs. Override with lib.mkForce to strip.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = map (name: {
      assertion = agents.${name}.uid != null;
      message = "castle.agents.${name}.uid must be set — nix-darwin does not auto-assign UIDs.";
    }) managedAgents;

    users.knownUsers = managedAgents;

    users.users = lib.listToAttrs (map (name: let u = agents.${name}; in {
      inherit name;
      value = {
        uid  = u.uid;
        home = "/Users/${name}";
        shell = shellFor u;
        openssh.authorizedKeys.keys = u.sshKeys;
      };
    }) managedAgents);

    # home-manager: applies to every managed identity — humans included.
    home-manager.useGlobalPkgs    = true;
    home-manager.useUserPackages  = true;
    home-manager.users = lib.listToAttrs (map (name: {
      inherit name;
      value = homeCfgFor name all.${name};
    }) managedAccts);
  };
}
