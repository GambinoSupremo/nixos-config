# NetworkManager, nftables firewall, Mullvad daemon, systemd-resolved.
{ config, pkgs, ... }:

{
  networking = {
    networkmanager.enable = true;

    # NixOS firewall wraps nftables directly — ufw is not needed.
    # Open specific ports here rather than via ufw rules.
    firewall = {
      enable = true;
      # Sunshine streaming ports are opened by services.sunshine.openFirewall
      # (nixos/features/sunshine.nix).
    };
  };

  # Mullvad daemon. First boot: mullvad account login
  services.mullvad-vpn = {
    enable     = true;
    gui.enable = true;
  };

  # systemd-resolved for local DNS caching.
  # DNSSEC must be false — it breaks Mullvad's DNS.
  services.resolved = {
    enable  = true;
    settings.Resolve.DNSSEC = "false";
    # Don't set domains = [ "~." ] here — let Mullvad manage the split-tunnel DNS
  };
}
