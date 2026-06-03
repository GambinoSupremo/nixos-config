{ config, pkgs, inputs, ... }:

{
  imports = [
    # MangoWM NixOS module — provides programs.mango.* options
    inputs.mangowm.nixosModules.mango
  ];

  # ── Compositors ───────────────────────────────────────────────────────────────
  # MangoWM — dwl-based, your primary compositor.
  # The flake provides the NixOS module and registers a SDDM session.
  # Disabled in hosts/vm/default.nix (needs GPU); enabled here as the default.
  programs.mango = {
    enable = true;
    # See https://mangowm.github.io/docs/nix-options for all module options
  };

  # Niri — scrolling compositor, your secondary. Also in nixpkgs.
  programs.niri.enable = true;

  # ── Display Manager ───────────────────────────────────────────────────────────
  services.displayManager.sddm = {
    enable         = true;
    wayland.enable = true;
    # MangoWM registers itself as a session via addLoginEntry (default: true).
    # On physical machine, set MangoWM as the default:
    defaultSession = "mango";   # override to "niri" in hosts/vm/default.nix if desired
    # sddm-silent-theme-git is AUR-only; package it yourself or leave unset for now.
    # theme = "sddm-silent";
  };

  # ── XDG Portals ───────────────────────────────────────────────────────────────
  # Two compositors, two portal needs:
  #   MangoWM (wlroots) → xdg-desktop-portal-wlr for screencasting
  #   Niri (not wlroots) → xdg-desktop-portal-gnome for screencasting
  # Both are included; the portal config routes per-compositor.
  xdg.portal = {
    enable       = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-wlr    # MangoWM / wlroots screencasting (OBS)
      xdg-desktop-portal-gnome  # Niri screencasting
      xdg-desktop-portal-gtk    # file dialogs everywhere
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

  # ── upower ────────────────────────────────────────────────────────────────────
  # Required by Noctalia for battery widget
  services.upower.enable = true;

  # ── Polkit ────────────────────────────────────────────────────────────────────
  security.polkit.enable = true;

  # ── GNOME Keyring ─────────────────────────────────────────────────────────────
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;

  # ── Fonts ─────────────────────────────────────────────────────────────────────
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      cantarell-fonts
      noto-fonts
      noto-fonts-cjk-sans       # was noto-fonts-cjk
      noto-fonts-emoji
      dejavu_fonts              # was ttf-dejavu
      liberation_ttf            # was ttf-liberation
      open-sans                 # was ttf-opensans
      bitstream-vera            # was ttf-bitstream-vera
      awesome-terminal-fonts
      # nixpkgs 24.11+ split style — if this errors try:
      # (nerdfonts.override { fonts = [ "Meslo" ]; })
      nerd-fonts.meslo-lg
    ];
    fontconfig.defaultFonts = {
      serif     = [ "Noto Serif" ];
      sansSerif = [ "Noto Sans" ];
      monospace = [ "MesloLGS Nerd Font Mono" ];
      emoji     = [ "Noto Color Emoji" ];
    };
  };
}
