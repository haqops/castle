{ config, lib, pkgs, ... }: let
  cfg = config.castle.services.discourse;
  users = config.castle.users;
  adminNames = builtins.filter (n: users.${n}.admin) (builtins.attrNames users);
  adminName = if adminNames == [] then null else builtins.head adminNames;
  # nixpkgs discourse module puts unicorn here; caddy proxies to it
  unicornSocket = "/run/discourse/sockets/unicorn.sock";
in {
  options.castle.services.discourse = {
    enable = lib.mkEnableOption "Discourse (long-form discussion)";
    domain = lib.mkOption {
      type = lib.types.str;
      description = "Public domain, e.g. \"discourse.example.com\". Cloudflare Origin CA cert must cover it.";
    };
    smtp = {
      host = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "SMTP server hostname. If null, outgoing mail is disabled.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 587;
      };
      username = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
      };
      fromAddress = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "From: address for outgoing mail. Defaults to noreply@<domain>.";
      };
    };
    s3 = {
      endpoint = lib.mkOption {
        type = lib.types.str;
        example = "https://<account_id>.r2.cloudflarestorage.com";
        description = "S3-compatible endpoint (Cloudflare R2 recommended).";
      };
      uploadsBucket = lib.mkOption {
        type = lib.types.str;
        description = "Bucket for user-uploaded files.";
      };
      backupsBucket = lib.mkOption {
        type = lib.types.str;
        description = "Bucket for periodic backups.";
      };
      region = lib.mkOption {
        type = lib.types.str;
        default = "auto";
        description = "S3 region. \"auto\" for Cloudflare R2.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [{
      assertion = adminName != null;
      message = "castle.services.discourse requires at least one castle.users entry with admin = true";
    }];

    castle.postgres.enable = lib.mkDefault true;
    castle.caddy.enable    = lib.mkDefault true;
    castle.redis.enable    = lib.mkDefault true;
    castle.caddy.virtualHosts.${cfg.domain} = "unix/${unicornSocket}";

    # Discourse's module creates its own redis-discourse.service iff redis.host
    # is "localhost" or "127.0.0.1". Point it at a /etc/hosts alias that
    # resolves to loopback but reads as "external" to the module, so it skips
    # spawning its own instance and shares castle.redis with Zulip.
    networking.hosts."127.0.0.1" = [ "castle-redis" ];

    sops.secrets = lib.mkMerge [
      {
        "discourse/secret-key-base"      = { owner = "discourse"; group = "discourse"; mode = "0400"; };
        "discourse/s3-access-key-id"     = { owner = "discourse"; group = "discourse"; mode = "0400"; };
        "discourse/s3-secret-access-key" = { owner = "discourse"; group = "discourse"; mode = "0400"; };
      }
      (lib.mkIf (cfg.smtp.host != null) {
        "discourse/smtp-password" = { owner = "discourse"; group = "discourse"; mode = "0400"; };
      })
    ];

    # Discourse needs to read the admin's password from users/<admin>/password.
    users.users.discourse.extraGroups = [ "castle-user-secrets" ];
    # /run/discourse/sockets/ is 0750 owned by discourse — caddy can't traverse
    # unless it's in the group.
    users.users.caddy.extraGroups = [ "discourse" ];

    # With nginx disabled, Rails itself has to serve /assets/*. In production
    # it does that only when RAILS_SERVE_STATIC_FILES is set.
    systemd.services.discourse.environment.RAILS_SERVE_STATIC_FILES = "1";

    # The upstream discourse module hard-codes systemd dependencies on
    # redis-discourse.service; since we point at castle-redis instead, that
    # unit doesn't exist and systemd refuses to start discourse.service.
    # Drop the stale references.
    systemd.services.discourse.requires = lib.mkForce [];
    systemd.services.discourse.bindsTo  = lib.mkForce [];

    services.discourse = {
      enable = true;
      hostname = cfg.domain;

      # We front discourse with our own Caddy instead of the built-in nginx.
      nginx.enable = false;
      enableACME = false;

      admin = {
        username = adminName;
        email = users.${adminName}.email;
        fullName = adminName;
        passwordFile = config.sops.secrets."users/${adminName}/password".path;
      };

      secretKeyBaseFile = config.sops.secrets."discourse/secret-key-base".path;

      # Share castle.redis with other services. dbNumber = 1 keeps Discourse's
      # keyspace separate from Zulip's (which uses db 0).
      redis = {
        host = "castle-redis";
        dbNumber = 1;
      };

      # We run a shared castle.postgres (17). Discourse's module asserts on
      # PostgreSQL 15, which is a conservative default: 17 works with
      # Discourse in practice.
      database.ignorePostgresqlVersion = true;

      mail = {
        notificationEmailAddress = if cfg.smtp.fromAddress != null
          then cfg.smtp.fromAddress
          else "noreply@${cfg.domain}";
      } // lib.optionalAttrs (cfg.smtp.host != null) {
        outgoing = {
          serverAddress = cfg.smtp.host;
          port = cfg.smtp.port;
          username = cfg.smtp.username;
          passwordFile = config.sops.secrets."discourse/smtp-password".path;
        };
      };

      siteSettings = {
        security.force_https = lib.mkForce true;
        files = {
          enable_s3_uploads    = true;
          s3_region            = cfg.s3.region;
          s3_endpoint          = cfg.s3.endpoint;
          s3_upload_bucket     = cfg.s3.uploadsBucket;
          s3_backup_bucket     = cfg.s3.backupsBucket;
          s3_access_key_id     = { _secret = config.sops.secrets."discourse/s3-access-key-id".path; };
          s3_secret_access_key = { _secret = config.sops.secrets."discourse/s3-secret-access-key".path; };
          enable_backups       = true;
          backup_location      = "s3";
        };
      };
    };
  };
}
