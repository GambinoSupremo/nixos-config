{ config, pkgs, ... }:

{
  networking = {
    networkmanager.enable = true;

    # NixOS firewall wraps nftables directly — ufw is not needed.
    # Open specific ports here rather than via ufw rules.
    firewall = {
      enable = true;
      # Sunshine streaming ports — uncomment on physical machine
      # allowedTCPPorts = [ 47984 47989 48010 ];
      # allowedUDPPorts = [ 47998 47999 48000 ];
    };
  };

  # Mullvad VPN daemon.
  # After first boot: mullvad account login <your-account-number>
  # package = pkgs.mullvad-vpn so the daemon binary comes from the same 2026.3 derivation
  # as the GUI. The default (pkgs.mullvad) is the headless daemon-only package which can
  # lag behind the GUI release and produce the "inconsistent version" out-of-sync error.
  services.mullvad-vpn = {
    enable  = true;
    package = pkgs.mullvad-vpn;
  };

  # systemd-resolved for local DNS caching.
  # DNSSEC must be false — it breaks Mullvad's DNS.
  services.resolved = {
    enable  = true;
    settings.Resolve.DNSSEC = "false";
    # Don't set domains = [ "~." ] here — let Mullvad manage the split-tunnel DNS
  };
}
