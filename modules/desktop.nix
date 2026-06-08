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
  # tuigreet reads /share/wayland-sessions to list available compositors.
  # MangoWM and Niri both register session files via their NixOS modules.
  # The VM host overrides the default_session command to drop straight into Niri.
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

  # Suppress the greetd "Welcome to..." getty on tty1 competing with the greeter
  systemd.services.greetd.serviceConfig.TTYPath = "/dev/tty2";

  # ── XDG Portals ───────────────────────────────────────────────────────────────
  xdg.portal = {
    enable       = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config = {
      mango = {
        default = [ "wlr" "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast"  = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot"  = [ "wlr" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      niri = {
        default = [ "gnome" "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast"  = [ "gnome" ];
        "org.freedesktop.impl.portal.Screenshot"  = [ "gnome" ];
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
