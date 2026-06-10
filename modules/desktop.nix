{ config, pkgs, inputs, ... }:

{
  imports = [
    # MangoWM NixOS module — provides programs.mango.* options
    inputs.mangowm.nixosModules.mango
  ];

  # ── Compositors ───────────────────────────────────────────────────────────────
  # MangoWM — dwl-based, primary compositor.
  # The module registers a session (share/wayland-sessions/mango.desktop) via
  # addLoginEntry (default true) and configures its own wlr/gtk portals.
  programs.mango.enable = true;

  # Niri — scrolling compositor, secondary. The nixpkgs module registers the
  # session and the gnome/gtk portal config for it.
  programs.niri.enable = true;

  # Hyprland — fallback session. Built with systemd support, so it starts
  # hyprland-session.target → graphical-session.target → noctalia.service.
  programs.hyprland.enable = true;

  # ── Display Manager ───────────────────────────────────────────────────────────
  services.displayManager.sddm = {
    enable         = true;
    wayland.enable = true;   # Wayland greeter
    # sddm-silent-theme-git is AUR-only; package it yourself or leave unset.
    # theme = "sddm-silent";
  };

  # Session names are the wayland-sessions desktop file basenames:
  #   mango.desktop → "mango", niri.desktop → "niri", hyprland.desktop → "hyprland"
  # Verify with: ls /run/current-system/sw/share/wayland-sessions
  services.displayManager.defaultSession = "mango";

  # ── XDG Portals ───────────────────────────────────────────────────────────────
  # The mango, niri, and hyprland modules each register their own portal
  # backends and per-compositor routing. Only the shared fallback lives here.
  xdg.portal = {
    enable        = true;
    extraPortals  = [ pkgs.xdg-desktop-portal-gtk ];  # file dialogs everywhere
    config.common.default = [ "gtk" ];
  };

  # ── upower ────────────────────────────────────────────────────────────────────
  # Required by Noctalia for the battery widget
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
      ttf_bitstream_vera        # was ttf-bitstream-vera
      nerd-fonts.meslo-lg       # was ttf-meslo-nerd
    ];
    fontconfig.defaultFonts = {
      serif     = [ "Noto Serif" ];
      sansSerif = [ "Noto Sans" ];
      monospace = [ "MesloLGS Nerd Font Mono" ];
      emoji     = [ "Noto Color Emoji" ];
    };
  };
}
