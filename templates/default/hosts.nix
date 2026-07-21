# Register of hosts for this castle instance.
#
# Each host is a NixOS module. Set castle options; add extra imports if needed.
# mkHost auto-imports castle.nixosModules.default and (unless `disk = null`)
# castle.diskoConfigs.<disk>, defaulting to "zfs-single".
#
# If this file will end up in a public repo, gitignore it and keep only your
# own private copy.
castle: {
  # Typical Hetzner Cloud VM — everything is defaults.
  # my-host = {
  #   castle.host.ipv4    = "203.0.113.42";
  #   castle.host.sshKeys = [ "ssh-ed25519 AAAA... you@laptop" ];
  # };

  # Tuning some options.
  # tuned = {
  #   castle.host.ipv4       = "203.0.113.43";
  #   castle.host.sshKeys    = [ "ssh-ed25519 AAAA..." ];
  #   castle.initrdSsh.port  = 22222;
  #   castle.zfs.autoScrub   = false;
  # };

  # Bare metal / non-Hetzner: bring your own hardware-config and disko.
  # bastion = {
  #   disk = null;                    # opt out of built-in disko
  #   imports = [
  #     ./hardware/bastion.nix
  #     ./disko/bastion.nix
  #   ];
  #   castle.host.ipv4      = "10.0.0.5";
  #   castle.host.sshKeys   = [ "ssh-ed25519 AAAA..." ];
  #   castle.hetzner.enable = false;
  # };
}
