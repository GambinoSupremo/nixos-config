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
  services.mullvad-vpn.enable = true;

  # systemd-resolved for local DNS caching.
  # DNSSEC must be false — it breaks Mullvad's DNS.
  services.resolved = {
    enable  = true;
    settings.Resolve.DNSSEC = "false";
    # Don't set domains = [ "~." ] here — let Mullvad manage the split-tunnel DNS
  };
}
