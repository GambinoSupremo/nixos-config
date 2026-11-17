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

  # --- DNS ---
  # DNSSEC stays off, it breaks Mullvad's DNS. Don't set domains here either.
  services.resolved = {
    enable = true;
    settings.Resolve.DNSSEC = "false";
  };
}
