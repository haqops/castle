{ config, lib, ... }: let
  cfg = config.castle.services.forgejo;
  port = 3000;
in {
  options.castle.services.forgejo = {
    enable = lib.mkEnableOption "Forgejo (git hosting + CI)";
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Public domain, e.g. \"git.example.com\". Cloudflare Origin CA cert must cover it.";
    };
  };

  config = lib.mkIf cfg.enable {
    castle.postgres.enable = lib.mkDefault true;
    castle.caddy.enable    = lib.mkDefault true;
    castle.caddy.virtualHosts.${cfg.domain} = port;

    services.forgejo = {
      enable = true;
      database.type = "postgres";
      settings = {
        server = {
          DOMAIN     = cfg.domain;
          ROOT_URL   = "https://${cfg.domain}/";
          HTTP_ADDR  = "127.0.0.1";
          HTTP_PORT  = port;
          PROTOCOL   = "http";
        };
        service = {
          DISABLE_REGISTRATION = true;
        };
        session.COOKIE_SECURE = true;
      };
    };
  };
}
