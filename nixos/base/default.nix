# Settings every host shares. Keep this order; changing it rebuilds the
# system for no reason.
{
  imports = [
    ./core.nix # time zone, Nix settings
    ./users.nix
    ./networking.nix # firewall, Mullvad, DNS
    ./desktop.nix # login screen, Hyprland, fonts
    ./audio.nix
    ./services.nix # keyd, Bluetooth, printer, SSH
    ./packages.nix # installed programs
  ];
}
