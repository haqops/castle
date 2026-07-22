# Register of identities and hosts for this castle instance.
#
# `humans` and `agents` are the two global registries. Both use the same
# submodule — the bucket is the signal to castle whether the identity should
# be created via SetupAssistant (humans on darwin, so they get SecureToken
# and can unlock FileVault) or declaratively by castle (agents everywhere;
# humans on Linux). Both feed the same list of service accounts.
#
# `hosts` is a NixOS module per box. Set castle.* options; add extra imports if
# needed. The library auto-imports castle.nixosModules.default and (unless
# `disk = null`) castle.diskoConfigs.<disk>, defaulting to "zfs-single".
#
# If this file will end up in a public repo, gitignore it and keep only your
# own private copy.
castle: {
  humans = {
    # you = {
    #   email    = "you@example.com";
    #   admin    = true;
    #   sshKeys  = [ "ssh-ed25519 AAAA... you@laptop" ];
    #   shell    = "zsh";
    #   editor   = "nvim";
    #   tools    = [ "gh" "delta" ];               # on top of the tower defaults
    # };
  };

  agents = {
    # you-claude = {
    #   email    = "you-claude@example.com";
    #   sshKeys  = [ "ssh-ed25519 AAAA... you-claude@studio" ];
    #   tools    = [ "claude-code" ];
    # };
  };

  hosts = {
    # Typical Hetzner Cloud VM — everything is defaults.
    # my-host = {
    #   castle.host.ipv4    = "203.0.113.42";
    #   castle.host.sshKeys = [ "ssh-ed25519 AAAA... you@laptop" ];
    # };

    # Running Forgejo + Discourse behind Cloudflare Origin CA.
    # Prereqs: sops-encrypted `caddy/origin.crt` and `caddy/origin.key`;
    # see README for the CF setup + `.sops.yaml` skeleton.
    # citadel = {
    #   castle.host.ipv4     = "203.0.113.42";
    #   castle.host.sshKeys  = [ "ssh-ed25519 AAAA..." ];
    #   sops.defaultSopsFile = ./secrets/citadel.yaml;
    #   castle.services.forgejo = {
    #     enable = true;
    #     domain = "git.example.com";
    #   };
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
  };
}
