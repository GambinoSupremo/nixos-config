{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    inputs.mangowm.nixosModules.mango
  ];

  # ── Compositors ───────────────────────────────────────────────────────────────
  programs.mango = {
    enable = true;
  };

  programs.niri.enable = true;

  # Hyprland — tertiary compositor
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # ── Display Manager — greetd + tuigreet ───────────────────────────────────────
  services.greetd = {
    enable = true;
    settings = {
      default_session = {
        command = lib.concatStringsSep " " [
          "${pkgs.greetd.tuigreet}/bin/tuigreet"
          "--time"
          "--remember"
          "--remember-session"
          "--sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
        ];
      };
    };
  };

  systemd.services.greetd.serviceConfig.TTYPath = "/dev/tty2";

  # ── XDG Portals ───────────────────────────────────────────────────────────────
  # MangoWM's NixOS module owns the `mango` portal config — we don't set it here.
  xdg.portal = {
    enable       = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config = {
      niri = {
        default = [ "gnome" "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast"  = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot"  = [ "gnome" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      hyprland = {
        default = [ "hyprland" "gtk" ];
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
  security.pam.services.greetd.enableGnomeKeyring = true;

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
    ];
    fontconfig.defaultFonts = {
      serif     = [ "Noto Serif" ];
      sansSerif = [ "Noto Sans" ];
      monospace = [ "MesloLGS Nerd Font Mono" ];
      emoji     = [ "Noto Color Emoji" ];
    };
  };
}
