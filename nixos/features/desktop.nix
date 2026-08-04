# Graphical stack: SDDM plus the three Wayland sessions (Mango primary,
# Niri secondary, Hyprland tertiary/HDR) with portals, keyring, and fonts.
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # MangoWM NixOS module — provides programs.mango.* options
    inputs.mangowm.nixosModules.mango
  ];

  # ── Compositors ───────────────────────────────────────────────────────────────
  # MangoWM — dwl-based, primary; module registers the session + its portals.
  programs.mango.enable = true;

  # Niri — secondary; nixpkgs module registers session + portal config.
  programs.niri.enable = true;

  # Hyprland — fallback. Session env / noctalia startup driven by
  # hyprSessionBootstrap in home/dotfiles.nix (the bare target raced noctalia).
  programs.hyprland = {
    enable    = true;
    # false alone doesn't drop the duplicate SDDM entry — the package ships
    # hyprland-uwsm.desktop itself; the symlinkJoin strips that one file.
    withUWSM  = false;
    # The module calls .override on the package, so the wrapper re-exposes it
    # (re-stripping after any override) plus the attrs the module reads.
    package   =
      let
        stripUwsmSession = hl: pkgs.symlinkJoin {
          name = "hyprland-single-session";
          paths = [ hl ];
          postBuild = "rm $out/share/wayland-sessions/hyprland-uwsm.desktop";
          inherit (hl) version meta;
          passthru = hl.passthru or {} // {
            inherit (hl) man;
            providedSessions = [ "hyprland" ];
            override = args: stripUwsmSession (hl.override args);
          };
        };
      in stripUwsmSession pkgs.hyprland;
  };

  # ── Display Manager ───────────────────────────────────────────────────────────
  services.displayManager.sddm = {
    enable = true;
    # Wayland greeter on kwin: the X11 greeter fails to respawn after logout on
    # this NVIDIA box (black screen). mkForce beats SilentSDDM's !xserver.enable.
    wayland.enable = lib.mkForce true;
    wayland.compositor = "kwin";
    # Empty X11 SessionDir hides the "Plasma (X11)" entry from the session list.
    settings.X11.SessionDir = "/var/empty";
  };

  # Fallback preselection only (SDDM remembers last-used); keep it on the daily
  # driver — defaulting to hyprland once landed a quick login in the wrong WM.
  services.displayManager.defaultSession = "niri";

  # ── XDG Portals ───────────────────────────────────────────────────────────────
  # Each compositor module registers its own backends; only the shared fallback here.
  xdg.portal = {
    enable       = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];  # file dialogs everywhere
    config = {
      KDE.default    = [ "kde" "gtk" ];  # KDE session: kde portal first, gtk fallback
      common.default = [ "gtk" ];        # all other sessions unchanged
    };
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
      noto-fonts
      noto-fonts-cjk-sans       # was noto-fonts-cjk
      noto-fonts-color-emoji    # top-level noto-fonts-emoji became a throw alias 2025-10-27
      dejavu_fonts              # was ttf-dejavu
      liberation_ttf            # was ttf-liberation
      open-sans                 # was ttf-opensans
      ttf_bitstream_vera        # was ttf-bitstream-vera
      nerd-fonts.meslo-lg       # was ttf-meslo-nerd; kept as fallback
      nerd-fonts.jetbrains-mono
    ];
    fontconfig.defaultFonts = {
      serif     = [ "Noto Serif" ];
      sansSerif = [ "Noto Sans" ];
      monospace = [ "JetBrainsMono Nerd Font Mono" ];
      emoji     = [ "Noto Color Emoji" ];
    };
  };
}
