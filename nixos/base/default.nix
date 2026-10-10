# Shared by every host. Order matters only for the system hash (list options
# merge in import order), not behaviour.
{
  imports = [
    ./core.nix # nix settings, locale, GC
    ./users.nix
    ./networking.nix # NetworkManager, firewall, Mullvad, resolved
    ./desktop.nix # SDDM, Hyprland (+ optional Mango/Niri), portals, fonts
    ./audio.nix # PipeWire
    ./services.nix # keyd, bluetooth, openrazer, ...
    ./packages.nix # systemPackages
  ];
}
