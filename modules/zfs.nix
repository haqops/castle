{ config, lib, ... }: let
  cfg = config.castle.zfs;
in {
  options.castle.zfs = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable ZFS runtime (encrypted rpool, autoScrub, trim).";
    };
    autoScrub = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Weekly ZFS scrub of all pools.";
    };
  };

  config = lib.mkIf cfg.enable {
    boot.supportedFilesystems = [ "zfs" ];
    boot.zfs.forceImportRoot = false;
    boot.zfs.requestEncryptionCredentials = true;

    services.zfs = {
      autoScrub.enable = cfg.autoScrub;
      trim.enable = true;
    };
  };
}
