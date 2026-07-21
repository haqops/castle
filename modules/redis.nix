{ config, lib, ... }: let
  cfg = config.castle.redis;
in {
  options.castle.redis = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the shared Redis instance. Auto-enabled by services that need
        it — you don't set this yourself.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    services.redis.servers."" = {
      enable = true;
      bind = "127.0.0.1";
      port = 6379;
    };
  };
}
