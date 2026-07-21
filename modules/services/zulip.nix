{ config, lib, pkgs, ... }: let
  cfg = config.castle.services.zulip;
  users = config.castle.users;
  adminNames = builtins.filter (n: users.${n}.admin) (builtins.attrNames users);
  adminName = if adminNames == [] then null else builtins.head adminNames;
  adminEmail = if adminName == null then null else users.${adminName}.email;

  # Podman's default bridge gateway — the IP a container uses to reach the
  # host. `host.containers.internal` also resolves to this on podman 4+.
  hostFromContainer = "host.containers.internal";
  bridgeCidr        = "10.88.0.0/16";
in {
  options.castle.services.zulip = {
    enable = lib.mkEnableOption "Zulip (real-time chat with movable topics)";
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Public domain, e.g. \"zulip.example.com\".";
    };
    image = lib.mkOption {
      type = lib.types.str;
      default = "zulip/docker-zulip:10.0-0";
      description = "OCI image tag for zulip-app.";
    };
    s3 = {
      endpoint = lib.mkOption {
        type = lib.types.str;
        example = "https://<account_id>.r2.cloudflarestorage.com";
      };
      uploadsBucket = lib.mkOption { type = lib.types.str; };
      avatarsBucket = lib.mkOption { type = lib.types.str; };
      backupsBucket = lib.mkOption { type = lib.types.str; };
      region        = lib.mkOption { type = lib.types.str; default = "auto"; };
    };
    smtp = {
      host        = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      port        = lib.mkOption { type = lib.types.port; default = 587; };
      username    = lib.mkOption { type = lib.types.nullOr lib.types.str; default = null; };
      fromAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "From address for outgoing mail. Defaults to noreply@<domain>.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = adminName != null;
      message = "castle.services.zulip requires at least one castle.users entry with admin = true";
    }];

    ## Shared castle infra
    castle.postgres.enable = lib.mkDefault true;
    castle.redis.enable    = lib.mkDefault true;
    castle.caddy.enable    = lib.mkDefault true;
    castle.caddy.virtualHosts.${cfg.domain} = "127.0.0.1:8080";

    ## Postgres — create db + user, allow password auth from podman bridge
    services.postgresql = {
      enableTCPIP = true;
      settings.listen_addresses = lib.mkForce "127.0.0.1,10.88.0.1";
      ensureDatabases = [ "zulip" ];
      ensureUsers = [{
        name = "zulip";
        ensureDBOwnership = true;
      }];
      authentication = lib.mkAfter ''
        # Zulip container reaches postgres via podman bridge with md5 auth.
        host zulip zulip ${bridgeCidr} scram-sha-256
      '';
    };

    # Apply zulip's postgres password after postgres starts. ensureUsers can't
    # set passwords, so do it once here.
    systemd.services.postgresql.postStart = lib.mkAfter ''
      pw=$(cat ${config.sops.secrets."zulip/postgres-password".path})
      $PSQL -tAc "ALTER USER zulip WITH PASSWORD '$pw';"
    '';

    ## Redis — bind to loopback + podman bridge
    services.redis.servers."".bind = lib.mkForce "127.0.0.1 10.88.0.1";

    ## RabbitMQ (native, dedicated to zulip)
    services.rabbitmq = {
      enable = true;
      listenAddress = "10.88.0.1";
      plugins = [ "rabbitmq_management" ];
    };
    # Zulip's rabbitmq user + password + permissions applied after rabbitmq starts.
    systemd.services.rabbitmq.postStart = lib.mkAfter ''
      pw=$(cat ${config.sops.secrets."zulip/rabbitmq-password".path})
      ${pkgs.rabbitmq-server}/bin/rabbitmqctl add_user zulip "$pw" 2>/dev/null || \
        ${pkgs.rabbitmq-server}/bin/rabbitmqctl change_password zulip "$pw"
      ${pkgs.rabbitmq-server}/bin/rabbitmqctl set_permissions zulip '.*' '.*' '.*'
    '';

    ## Memcached
    services.memcached = {
      enable = true;
      listen = "10.88.0.1";
      port   = 11211;
    };

    ## Firewall — open the podman bridge to host services
    networking.firewall.trustedInterfaces = [ "podman0" ];

    ## Sops secrets
    sops.secrets = {
      "zulip/postgres-password" = { owner = "postgres"; mode = "0400"; };
      "zulip/rabbitmq-password" = { owner = "rabbitmq"; mode = "0400"; };
      "zulip/secret-key"        = { mode = "0444"; };
      "zulip/s3-access-key-id"  = { mode = "0444"; };
      "zulip/s3-secret-access-key" = { mode = "0444"; };
    } // lib.optionalAttrs (cfg.smtp.host != null) {
      "zulip/smtp-password" = { mode = "0444"; };
    };

    ## Env file for the zulip container, rendered with sops secrets inline.
    sops.templates."zulip.env" = {
      content = ''
        SETTING_EXTERNAL_HOST=${cfg.domain}
        SETTING_ZULIP_ADMINISTRATOR=${adminEmail}
        DISABLE_HTTPS=true
        LOADBALANCER_IPS=127.0.0.1
        SSL_CERTIFICATE_GENERATION=self-signed

        # Postgres (shared castle.postgres via podman bridge)
        DB_HOST=${hostFromContainer}
        DB_HOST_PORT=5432
        DB_USER=zulip
        DB_NAME=zulip
        SECRETS_postgres_password=${config.sops.placeholder."zulip/postgres-password"}

        # RabbitMQ (host)
        SETTING_RABBITMQ_HOST=${hostFromContainer}
        SETTING_RABBITMQ_USERNAME=zulip
        SECRETS_rabbitmq_password=${config.sops.placeholder."zulip/rabbitmq-password"}

        # Redis (shared castle.redis)
        SETTING_REDIS_HOST=${hostFromContainer}
        SETTING_REDIS_PORT=6379

        # Memcached (host)
        SETTING_MEMCACHED_LOCATION=${hostFromContainer}:11211

        # Django secret_key
        SECRETS_secret_key=${config.sops.placeholder."zulip/secret-key"}

        # S3-backed uploads (Cloudflare R2)
        SETTING_LOCAL_UPLOADS_DIR=None
        SETTING_S3_AUTH_UPLOADS_BUCKET=${cfg.s3.uploadsBucket}
        SETTING_S3_AVATAR_BUCKET=${cfg.s3.avatarsBucket}
        SETTING_S3_BACKUP_BUCKET=${cfg.s3.backupsBucket}
        SETTING_S3_REGION=${cfg.s3.region}
        SETTING_S3_ENDPOINT_URL=${cfg.s3.endpoint}
        SETTING_S3_KEY=${config.sops.placeholder."zulip/s3-access-key-id"}
        SETTING_S3_SECRET_KEY=${config.sops.placeholder."zulip/s3-secret-access-key"}

        # Registration closed by default
        SETTING_REGISTER_LINK_DISABLED=True
        SETTING_INVITE_REQUIRED_BY_DEFAULT=True
      '' + lib.optionalString (cfg.smtp.host != null) ''

        # SMTP
        SETTING_EMAIL_HOST=${cfg.smtp.host}
        SETTING_EMAIL_PORT=${toString cfg.smtp.port}
        SETTING_EMAIL_HOST_USER=${cfg.smtp.username}
        SETTING_EMAIL_USE_TLS=True
        SECRETS_email_password=${config.sops.placeholder."zulip/smtp-password"}
        SETTING_DEFAULT_FROM_EMAIL=${if cfg.smtp.fromAddress != null then cfg.smtp.fromAddress else "noreply@${cfg.domain}"}
      '';
      mode  = "0400";
      owner = "root";
      group = "root";
    };

    ## Persistent data dir on ZFS
    systemd.tmpfiles.rules = [
      "d /var/lib/zulip           0755 root root -"
      "d /var/lib/zulip/data      0755 root root -"
    ];

    ## OCI container
    virtualisation.oci-containers.backend = "podman";
    virtualisation.oci-containers.containers.zulip = {
      image = cfg.image;
      autoStart = true;
      environmentFiles = [ config.sops.templates."zulip.env".path ];
      ports = [ "127.0.0.1:8080:80" ];
      volumes = [ "/var/lib/zulip/data:/data" ];
      dependsOn = [];
      extraOptions = [
        "--add-host=host.containers.internal:host-gateway"
      ];
    };

    # Ensure the container systemd unit waits for the host services it depends on.
    systemd.services.${"podman-zulip"} = {
      after    = [ "postgresql.service" "redis-.service" "rabbitmq.service" "memcached.service" ];
      requires = [ "postgresql.service" "rabbitmq.service" "memcached.service" ];
    };
  };
}
