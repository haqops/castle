{ config, lib, pkgs, ... }: let
  cfg    = config.castle.tower;
  # On Linux towers we don't distinguish humans and agents at the account
  # level — both get a Unix account via users.users.<name>. The bucket only
  # matters on darwin (where humans are created via SetupAssistant).
  users  = config.castle.humans // config.castle.agents;
  accts  = cfg.accounts;

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

  resolveTools = names: map (n: pkgs.${n}) names;

  extraPkgsFor  = u: if u.extraPackages != null then u.extraPackages pkgs else [];
  editorPkgFor  = u: if u.editor != null then [ editorPkgs.${u.editor} ] else [];

  packagesFor = u:
    resolveTools (cfg.defaultTools ++ u.tools)
    ++ editorPkgFor u
    ++ extraPkgsFor u;

  shellFor = u:
    if u.shell != null then shellPkgs.${u.shell} else pkgs.bashInteractive;

  shellsInUse =
    lib.unique (lib.filter (s: s != null) (map (n: users.${n}.shell) accts));
in {
  options.castle.tower = {
    enable = lib.mkEnableOption "castle tower (workstation for humans and their agents)";

    accounts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Names from castle.users to provision as local Unix accounts on
        this tower. A user not listed here has no account here.
      '';
    };

    defaultTools = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "git" "gh" "direnv"
        "ripgrep" "fd" "bat" "eza"
        "jq" "yq"
        "less" "tmux"
        "openssh" "curl" "wget"
      ];
      description = ''
        Packages installed for every provisioned account, resolved by
        name against nixpkgs. Override with lib.mkForce to strip;
        each user can add on top via castle.users.<name>.tools.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    users.users = lib.listToAttrs (map (name: let
      u = users.${name};
    in {
      inherit name;
      value = {
        isNormalUser = true;
        home         = "/home/${name}";
        extraGroups  = lib.optional u.admin "wheel";
        openssh.authorizedKeys.keys = u.sshKeys;
        shell        = shellFor u;
        packages     = packagesFor u;
        description  = "castle user <${u.email}>";
      };
    }) accts);

    programs.zsh.enable  = builtins.elem "zsh"  shellsInUse;
    programs.fish.enable = builtins.elem "fish" shellsInUse;
  };
}
