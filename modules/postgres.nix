{ config, lib, pkgs, ... }: let
  cfg = config.castle.postgres;
in {
  options.castle.postgres = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable a shared PostgreSQL instance for castle services. Auto-enabled
        by services that need it (Forgejo, Discourse, Plane). Services use
        `services.postgresql.ensureDatabases`/`ensureUsers` with peer auth
        over the Unix socket — no passwords in configs.
      '';
    };
    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.postgresql_15;
      defaultText = lib.literalExpression "pkgs.postgresql_15";
    };
  };

  config = lib.mkIf cfg.enable {
    services.postgresql = {
      enable = true;
      package = cfg.package;
    };
  };
}
