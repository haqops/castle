{ config, lib, pkgs, ... }: let
  cfg = config.castle.services.forgejo;
  port = 3000;
in {
  options.castle.services.forgejo = {
    enable = lib.mkEnableOption "Forgejo (git hosting + CI)";
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Public domain, e.g. \"git.example.com\". Cloudflare Origin CA cert must cover it.";
    };
    admin = {
      username = lib.mkOption {
        type = lib.types.str;
        default = "admin";
        description = "Initial admin login; created on first activation if missing.";
      };
      email = lib.mkOption {
        type = lib.types.str;
        description = "Contact email for the admin user.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    castle.postgres.enable = lib.mkDefault true;
    castle.caddy.enable    = lib.mkDefault true;
    castle.caddy.virtualHosts.${cfg.domain} = port;

    sops.secrets."forgejo/admin-password" = {
      owner = "forgejo";
      group = "forgejo";
      mode = "0400";
    };

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

    systemd.services.forgejo-admin-init = {
      description = "Ensure the initial Forgejo admin user exists";
      after = [ "forgejo.service" ];
      requires = [ "forgejo.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ config.services.forgejo.package ];
      serviceConfig = {
        Type = "oneshot";
        User = "forgejo";
        Group = "forgejo";
        RemainAfterExit = true;
      };
      script = ''
        wd=${lib.escapeShellArg config.services.forgejo.stateDir}
        user=${lib.escapeShellArg cfg.admin.username}
        if forgejo --work-path "$wd" admin user list | tail -n +2 | awk '{print $2}' | grep -qxF "$user"; then
          echo "admin '$user' already exists — nothing to do"
          exit 0
        fi
        pw="$(cat ${config.sops.secrets."forgejo/admin-password".path})"
        forgejo --work-path "$wd" admin user create \
          --admin \
          --username "$user" \
          --email ${lib.escapeShellArg cfg.admin.email} \
          --password "$pw" \
          --must-change-password=false
      '';
    };
  };
}
