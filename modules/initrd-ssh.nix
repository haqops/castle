{ config, lib, ... }: let
  cfg = config.castle.initrdSsh;
in {
  options.castle.initrdSsh = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable systemd-initrd + SSH server for entering the ZFS passphrase remotely.";
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 2222;
      description = "TCP port for the initrd sshd.";
    };
    hostKeyPath = lib.mkOption {
      type = lib.types.path;
      default = "/etc/secrets/initrd/ssh_host_ed25519_key";
      description = "Path to the ed25519 host key used by the initrd sshd. Provisioned via `nixos-anywhere --extra-files`.";
    };
    authorizedKeys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = config.castle.host.sshKeys;
      defaultText = lib.literalExpression "config.castle.host.sshKeys";
      description = "SSH public keys allowed to unlock the box in initrd.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.initrd.systemd.enable = true;

    boot.initrd.systemd.network = {
      enable = true;
      networks."10-uplink" = {
        matchConfig.Type = "ether";
        networkConfig.DHCP = "yes";
      };
    };

    boot.initrd.network.ssh = {
      enable = true;
      port = cfg.port;
      hostKeys = [ cfg.hostKeyPath ];
      authorizedKeys = cfg.authorizedKeys;
    };

    # sshd's `PrintMotd yes` (default) means /etc/motd shows on login — turn
    # that into the unlock cheatsheet instead of trying to auto-run the query
    # (which would leave nowhere to go if unlock fails).
    boot.initrd.systemd.contents."/etc/motd".text = ''

      ── ${config.networking.hostName} initrd (root pool is locked)

      Unlock ZFS:   systemd-tty-ask-password-agent --query
      Inspect:      systemctl --failed ; journalctl -xb ; zpool status

    '';
  };
}
