{ config, lib, ... }: let
  cfg = config.castle.ssh;
in {
  options.castle.ssh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable openssh on the main system, key-only.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 22;
      description = "TCP port for sshd.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.openssh = {
      enable = true;
      ports = [ cfg.port ];
      settings = {
        PermitRootLogin = "prohibit-password";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
      openFirewall = true;
    };

    networking.firewall = {
      enable = true;
      allowedTCPPorts = [ cfg.port ];
    };
  };
}
