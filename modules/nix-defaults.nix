{ config, lib, pkgs, ... }: let
  cfg = config.castle.nixDefaults;
in {
  options.castle.nixDefaults = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable castle's Nix defaults (flakes, GC, TZ, locale, small CLI toolbox).";
    };
    timeZone = lib.mkOption {
      type = lib.types.str;
      default = "UTC";
      description = "System time zone.";
    };
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional packages to add to the base toolbox.";
    };
  };

  config = lib.mkIf cfg.enable {
    nix.settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      trusted-users = [ "root" ];
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };

    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    time.timeZone = cfg.timeZone;
    i18n.defaultLocale = "en_US.UTF-8";

    environment.systemPackages = (with pkgs; [
      git vim htop curl wget rsync tmux
    ]) ++ cfg.extraPackages;
  };
}
