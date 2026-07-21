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
      type = lib.types.attrsOf lib.types.port;
      default = {};
      description = ''
        Map of `domain → local port`. Service modules register their vhost
        here (e.g. `castle.caddy.virtualHosts."git.example.com" = 3000`).
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
      virtualHosts = lib.mapAttrs (domain: port: {
        extraConfig = ''
          tls ${config.sops.secrets."caddy/origin.crt".path} ${config.sops.secrets."caddy/origin.key".path}
          reverse_proxy 127.0.0.1:${toString port}
        '';
      }) cfg.virtualHosts;
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
