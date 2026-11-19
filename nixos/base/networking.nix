# Network, firewall, Mullvad VPN and DNS.
_:

{
  networking = {
    networkmanager.enable = true;
    # Sunshine opens its own ports (nixos/features/sunshine.nix).
    firewall.enable = true;
  };

  # --- Mullvad ---
  # After a fresh install: mullvad account login
  services.mullvad-vpn = {
    enable = true;
    gui.enable = true;
  };

  # --- LocalSend ---
  # AirDrop-style sharing with phones on the LAN; opens its port. With Mullvad
  # on, its "Local network sharing" setting must be enabled to be seen.
  programs.localsend.enable = true;

  # --- DNS ---
  # DNSSEC stays off, it breaks Mullvad's DNS. Don't set domains here either.
  services.resolved = {
    enable = true;
    settings.Resolve.DNSSEC = "false";
  };
}
