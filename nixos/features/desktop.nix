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
  # withUWSM=false alone is NOT enough to drop the duplicate SDDM entry: the
  # hyprland package itself ships hyprland-uwsm.desktop in
  # share/wayland-sessions and the module registers the whole package. The
  # symlinkJoin strips that one file without recompiling Hyprland.
  programs.hyprland = {
    enable    = true;
    withUWSM  = false;
    # The module calls .override on the package (wayland/lib.nix), so the
    # wrapper must re-expose it; the recursion re-strips after any override.
    package   =
      let
        stripUwsmSession = hl: pkgs.symlinkJoin {
          name = "hyprland-single-session";
          paths = [ hl ];
          postBuild = "rm $out/share/wayland-sessions/hyprland-uwsm.desktop";
          # The module also reads .version (xwayland default) and
          # meta.mainProgram (getExe) off the package; meta.outputsToInstall
          # names the man output, so expose it via passthru too.
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
    # Greeter display server is left to the SilentSDDM module, which drives it to
    # X11 (its theme targets X11, and X11 is the reliable path on this NVIDIA box).
    # Don't set wayland.enable here — it conflicts with SilentSDDM's definition.
    # The greeter's display server is independent of the session you pick: an X11
    # greeter still launches the Wayland sessions (mango/niri/hyprland) fine.
    #
    # Point X11 SessionDir at an empty path so the "Plasma (X11)" entry from
    # plasma-workspace.sessions doesn't appear in the SDDM session list.
    settings.X11.SessionDir = "/var/empty";
  };

  # Session names are the wayland-sessions desktop file basenames:
  #   mango.desktop → "mango", niri.desktop → "niri", hyprland.desktop → "hyprland"
  # Verify with: ls /run/current-system/sw/share/wayland-sessions
  services.displayManager.defaultSession = "hyprland";

  # ── XDG Portals ───────────────────────────────────────────────────────────────
  # The mango, niri, and hyprland modules each register their own portal
  # backends and per-compositor routing. Only the shared fallback lives here.
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
