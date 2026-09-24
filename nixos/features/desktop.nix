# Graphical stack: SDDM plus Hyprland (primary), Niri (backup) and KineticWE,
# with portals, keyring, and fonts.
{ config, lib, pkgs, inputs, ... }:

{
  imports = [ inputs.kineticwe.nixosModules.default ];

  # ── Compositors ───────────────────────────────────────────────────────────────
  # KineticWE — kwin-we + noctalia-kwe; user config in home/kineticwe.nix.
  programs.kineticwe.enable = true;

  # 2.0 lacks master's dontWrapQtApps fix for kdecoration-git; drop once merged.
  nixpkgs.overlays = lib.mkAfter [
    (final: prev:
      let
        kwe = inputs.kineticwe.packages.${final.stdenv.hostPlatform.system};
        kdecoration = kwe.kdecoration.overrideAttrs { dontWrapQtApps = true; };
        kinetic-we  = kwe.kinetic-we.override { kdecorationGit = kdecoration; };
      in {
        inherit kdecoration kinetic-we;
        kineticwe = kwe.session.override { kineticWe = kinetic-we; };
      })
  ];

  # Patched session launcher: see the notes on each substitution below.
  programs.kineticwe.package =
    let
      orig = pkgs.kineticwe;
      # noctalia's logout (terminate-session) kills sddm-helper and SDDM never
      # returns to the greeter; end the startup payload instead so kwin exits cleanly.
      loginctlShim = pkgs.writeShellScriptBin "loginctl" ''
        if [ "''${1-}" = terminate-session ] && [ "''${2-}" = "''${XDG_SESSION_ID-}" ] \
           && [ -n "''${KWE_PAYLOAD_PID-}" ]; then
          kill -TERM "$KWE_PAYLOAD_PID"; exit
        fi
        exec ${pkgs.systemd}/bin/loginctl "$@"
      '';
    in
    pkgs.runCommand "${orig.name}-qkdetheme-fix" {
      passthru = orig.passthru;
      meta     = orig.meta;
    } ''
      cp -r ${orig} $out
      chmod -R u+w $out
      # Exec= and the wrapper shim hardcode the original store path; repoint them.
      substituteInPlace "$out/share/wayland-sessions/KineticWE.desktop" \
        --replace-fail "${orig}/bin/start-kineticwe" "$out/bin/start-kineticwe"
      substituteInPlace "$out/bin/start-kineticwe" \
        --replace-fail "${orig}/bin/.start-kineticwe-wrapped" "$out/bin/.start-kineticwe-wrapped"
      # Run the per-user config hook; unset KDE_SESSION_VERSION for kwin only
      # (with KDE_FULL_SESSION it segfaults in Qt's QKdeTheme).
      substituteInPlace "$out/bin/.start-kineticwe-wrapped" \
        --replace-fail 'exec env XDG_CONFIG_HOME=' '[ -x "$HOME/.config/kineticwe/pre-start" ] && KWE_CONFIG_HOME="$KWE_CONFIG_HOME" "$HOME/.config/kineticwe/pre-start" >"$SESSION_LOG_DIR/pre-start.log" 2>&1 || true
      unset KDE_SESSION_VERSION
      exec env XDG_CONFIG_HOME='
      # Logout shim on the payload's PATH (children: noctalia).
      substituteInPlace "$out/bin/.start-kineticwe-wrapped" \
        --replace-fail 'export XDG_CONFIG_HOME="''${KWE_REAL_CONFIG_HOME:-$HOME/.config}"' 'export XDG_CONFIG_HOME="''${KWE_REAL_CONFIG_HOME:-$HOME/.config}"
      export KWE_PAYLOAD_PID=$$
      export PATH="${loginctlShim}/bin:$PATH"'
      if grep -rqF "${orig}" "$out"; then
        echo "kineticwe patch: $out still references ${orig}" >&2; exit 1
      fi
    '';

  # MangoWM disabled 2026-09-24; config still deployed from dotfiles/mango
  # (re-enable: mangowm input + its NixOS/HM modules, see git history).

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
      # mkForce over KineticWE's module (it's covered by KDE.default above).
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
