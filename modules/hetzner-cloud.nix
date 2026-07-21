{ config, lib, ... }: let
  cfg = config.castle.hetzner;
in {
  options.castle.hetzner = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Hetzner Cloud VM defaults (DHCP via networkd, virtio, serial console).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.qemuGuest.enable = true;

    boot.kernelParams = [ "console=tty1" "console=ttyS0,115200" ];
    boot.initrd.availableKernelModules = [
      "virtio_pci" "virtio_scsi" "virtio_blk" "virtio_net" "ata_piix" "ahci" "sd_mod"
    ];

    networking.useDHCP = false;
    networking.useNetworkd = true;
    systemd.network = {
      enable = true;
      networks."10-uplink" = {
        matchConfig.Type = "ether";
        networkConfig.DHCP = "yes";
      };
    };
  };
}
