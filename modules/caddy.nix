{ config, lib, ... }: let
  cfg = config.castle.caddy;
in {
  options.castle.caddy = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable Caddy as a reverse proxy fronting castle services with a
        Cloudflare Origin CA certificate. Auto-enabled by any service module
        that registers a virtualHost. TLS material comes from sops secrets
        `caddy/origin.crt` and `caddy/origin.key`.
      '';
    };
    virtualHosts = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = ''
        Map of `domain → reverse_proxy target`. The value is passed directly
        to Caddy's `reverse_proxy` directive; use either a `host:port`
        (e.g. `"127.0.0.1:3000"`) or a unix socket
        (`"unix//run/foo/sock"`). Service modules register their vhost here.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    sops.secrets."caddy/origin.crt" = {
      owner = "caddy";
      group = "caddy";
      mode = "0400";
    };
    sops.secrets."caddy/origin.key" = {
      owner = "caddy";
      group = "caddy";
      mode = "0400";
    };

    services.caddy = {
      enable = true;
      virtualHosts = lib.mapAttrs (_domain: target: {
        extraConfig = ''
          tls ${config.sops.secrets."caddy/origin.crt".path} ${config.sops.secrets."caddy/origin.key".path}
          reverse_proxy ${target}
        '';
      }) cfg.virtualHosts;
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
