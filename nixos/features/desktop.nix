# Graphical stack: SDDM plus the Wayland sessions (Hyprland primary, Mango
# and Niri backups, KineticWE experimental) with portals, keyring, and fonts.
{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # MangoWM NixOS module — provides programs.mango.* options
    inputs.mangowm.nixosModules.mango
    # KineticWE (kwin-we + noctalia) — registers the session with SDDM.
    inputs.kineticwe.nixosModules.default
  ];

  # ── Compositors ───────────────────────────────────────────────────────────────
  # KineticWE — kwin-we + noctalia. Experimental; previously removed
  # 2026-07-01 after login failures. Retrying now that other session bugs
  # (uwsm logout hang, hyprland-uwsm dupe) are fixed.
  programs.kineticwe.enable = true;

  # kinetic-we itself (not its startup payload) segfaults on every launch —
  # coredumpctl shows a null deref in Qt6Gui's built-in QKdeTheme init
  # (QStyleHintsPrivate::update). Cause: Qt's desktop-environment detection
  # (qdesktopunixservices.cpp) checks XDG_CURRENT_DESKTOP first, and if
  # empty, FALLS BACK to KDE_FULL_SESSION — either one alone is enough to
  # make Qt auto-load its crashing "kde" platform theme. Commenting out
  # this script's own `export` lines for both wasn't enough (verified by
  # grepping the actual crashed process's environment out of its coredump:
  # both were still "KDE"/"true") — SDDM itself injects XDG_CURRENT_DESKTOP
  # and KDE_FULL_SESSION into the session's environment upstream, based on
  # DesktopNames=KDE in KineticWE.desktop, before this script even runs.
  # Not re-exporting them doesn't clear an already-inherited value, so they
  # must be explicitly unset right before the exec. The startup payload
  # re-exports the full KDE identity env for noctalia/portals/child apps
  # independently (from its own heredoc, unaffected by this), so they still
  # see KDE correctly.
  programs.kineticwe.package =
    let
      orig = pkgs.kineticwe;
    in
    pkgs.runCommand "${orig.name}-no-qkdetheme-crash" {
      passthru = orig.passthru;
      meta     = orig.meta;
    } ''
      cp -r ${orig} $out
      chmod -R u+w $out
      sed -i \
        -e '0,/^export XDG_CURRENT_DESKTOP=KDE$/{s/^export XDG_CURRENT_DESKTOP=KDE$/# &  # removed: crashes kwin-we Qt6Gui init, see kineticwe-session-debugging memory/}' \
        -e '0,/^export KDE_FULL_SESSION=true$/{s/^export KDE_FULL_SESSION=true$/# &  # removed: Qt KDE-theme fallback trigger, same crash/}' \
        -e '/^exec "\$KINETIC_WE" --xwayland --exit-with-session "\$STARTUP_PAYLOAD"$/i\
unset XDG_CURRENT_DESKTOP KDE_FULL_SESSION\
env > "$HOME/kwe-preexec-env.log" 2>/dev/null || true' \
        "$out/bin/.start-kineticwe-wrapped"
      # The .desktop Exec= line is baked in at the ORIGINAL derivation's own
      # $out — cp -r doesn't rewrite file contents, so SDDM would otherwise
      # still launch the unpatched script from the old store path.
      substituteInPlace "$out/share/wayland-sessions/KineticWE.desktop" \
        --replace-fail "${orig}/bin/start-kineticwe" "$out/bin/start-kineticwe"
    '';

  # MangoWM — dwl-based, backup; module registers the session + its portals.
  programs.mango.enable = true;

  # Niri — backup; nixpkgs module registers session + portal config.
  programs.niri.enable = true;

  # Hyprland — primary/daily driver. Session env / noctalia startup driven by
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

  # Fallback preselection only (SDDM remembers last-used); Hyprland is the
  # daily driver.
  services.displayManager.defaultSession = "hyprland";

  # ── XDG Portals ───────────────────────────────────────────────────────────────
  # Each compositor module registers its own backends; only the shared fallback here.
  xdg.portal = {
    enable       = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];  # file dialogs everywhere
    config = {
      KDE.default    = [ "kde" "gtk" ];  # KDE session: kde portal first, gtk fallback
      # mkForce: KineticWE's own module (DesktopNames=KDE, so it's covered by
      # KDE.default above) also sets common.default = "kde" unconditionally —
      # this wins the merge so Hyprland/Niri/Mango keep gtk.
      common.default = lib.mkForce [ "gtk" ];
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
