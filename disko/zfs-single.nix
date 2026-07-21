{ ... }: {
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          boot-bios = {
            size = "1M";
            type = "EF02";
            priority = 1;
          };
          boot = {
            size = "1G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/boot";
            };
          };
          zfs = {
            size = "100%";
            content = {
              type = "zfs";
              pool = "rpool";
            };
          };
        };
      };
    };

    zpool.rpool = {
      type = "zpool";
      rootFsOptions = {
        compression   = "zstd";
        acltype       = "posixacl";
        xattr         = "sa";
        atime         = "off";
        mountpoint    = "none";
        canmount      = "off";
        encryption    = "aes-256-gcm";
        keyformat     = "passphrase";
        keylocation   = "prompt";
      };
      options = {
        ashift   = "12";
        autotrim = "on";
      };
      datasets = {
        "root" = {
          type = "zfs_fs";
          mountpoint = "/";
          options.mountpoint = "legacy";
        };
        "nix" = {
          type = "zfs_fs";
          mountpoint = "/nix";
          options.mountpoint = "legacy";
        };
        "home" = {
          type = "zfs_fs";
          mountpoint = "/home";
          options.mountpoint = "legacy";
        };
        "reserved" = {
          type = "zfs_fs";
          options = {
            mountpoint     = "none";
            canmount       = "off";
            refreservation = "1G";
          };
        };
      };
    };
  };

  boot.loader.grub = {
    enable = true;
    efiSupport = false;
  };
}
