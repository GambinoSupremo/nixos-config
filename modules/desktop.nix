{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    inputs.mangowm.nixosModules.mango
  ];

  # ── Compositors ───────────────────────────────────────────────────────────────
  programs.mango = {
    enable = true;
  };

  programs.niri = {
    enable = true;
  };

  # Hyprland — tertiary compositor
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # ── Display Manager — SDDM ────────────────────────────────────────────────────
  # SDDM gives us a graphical login/session picker instead of greetd autostart.
  # Use the session menu to choose MangoWM, Niri, or Hyprland.
  services.greetd.enable = lib.mkForce false;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Leave this unset if the exact Mango session name does not match.
  # SDDM will still show the session picker.
  # If Mango shows up under a different name, we can set this later.
  # services.displayManager.defaultSession = "mango";

  # Make compositor sessions visible to display managers.
  services.displayManager.sessionPackages = [
    config.programs.mango.package
    pkgs.niri
    pkgs.hyprland
  ];

  # ── XDG Portals ───────────────────────────────────────────────────────────────
  # MangoWM's NixOS module owns the `mango` portal config — we don't set it here.
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
      xdg-desktop-portal-hyprland
    ];
    config = {
      niri = {
        default = [ "gnome" "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "gnome" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      hyprland = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      common = {
        default = [ "gtk" ];
      };
    };
  };

  # ── Polkit ────────────────────────────────────────────────────────────────────
  security.polkit.enable = true;

  # ── GNOME Keyring ─────────────────────────────────────────────────────────────
  services.gnome.gnome-keyring.enable = true;

  security.pam.services.sddm.enableGnomeKeyring = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # ── upower ────────────────────────────────────────────────────────────────────
  services.upower.enable = true;

  # ── Fonts ─────────────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      cantarell-fonts
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      dejavu_fonts
      liberation_ttf
      nerd-fonts.meslo-lg
    ];
    fontconfig.defaultFonts = {
      serif = [ "Noto Serif" ];
      sansSerif = [ "Noto Sans" ];
      monospace = [ "MesloLGS Nerd Font Mono" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
