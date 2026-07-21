{ config, lib, pkgs, ... }: let
  cfg = config.castle.services.forgejo;
  port = 3000;
  users = config.castle.users;
  userNames = builtins.attrNames users;
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

    users.users.forgejo.extraGroups = [ "castle-user-secrets" ];

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

    systemd.services.forgejo-users-init = lib.mkIf (userNames != []) {
      description = "Provision Forgejo accounts for castle.users";
      after = [ "forgejo.service" ];
      requires = [ "forgejo.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        config.services.forgejo.package
        coreutils
        gawk
        gnugrep
      ];
      serviceConfig = {
        Type = "oneshot";
        User = "forgejo";
        Group = "forgejo";
        RemainAfterExit = true;
      };
      script = ''
        wd=${lib.escapeShellArg config.services.forgejo.stateDir}
        existing=$(forgejo --work-path "$wd" admin user list | tail -n +2 | awk '{print $2}')
        ${lib.concatMapStringsSep "\n" (name: let u = users.${name}; in ''
          if echo "$existing" | grep -qxF ${lib.escapeShellArg name}; then
            echo "user '${name}' already exists — skipping"
          else
            echo "creating user '${name}'${lib.optionalString u.admin " (admin)"}"
            pw="$(cat ${config.sops.secrets."users/${name}/password".path})"
            forgejo --work-path "$wd" admin user create \
              ${lib.optionalString u.admin "--admin \\"}
              --username ${lib.escapeShellArg name} \
              --email ${lib.escapeShellArg u.email} \
              --password "$pw" \
              --must-change-password=false
          fi
        '') userNames}
      '';
    };
  };
}
