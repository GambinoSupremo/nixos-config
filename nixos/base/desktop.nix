# Graphical stack: Noctalia Greeter (greetd) plus Hyprland, optional Mango and Niri sessions, with
# portals, keyring, and fonts.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.gav.sessions;
in
{
  # Spare compositors. Off by default; their configs stay in the dotfiles, and
  # home-manager and Sunshine follow these too.
  options.gav.sessions = {
    mango = lib.mkEnableOption "the Mango session";
    niri = lib.mkEnableOption "the niri session";
  };

  config = {
    # ── Compositors ───────────────────────────────────────────────────────────────
    # Flip either to true to bring that session back on the login screen.
    gav.sessions = {
      mango = true;
      niri = false;
    };

    # Mango — nixpkgs module registers the session + wlr portal config. Its
    # mango-session.target ships in share/systemd/user, which the module doesn't link.
    programs.mango.enable = cfg.mango;
    systemd.packages = lib.mkIf cfg.mango [ config.programs.mango.package ];

    # Niri — nixpkgs module registers session + portal config.
    programs.niri.enable = cfg.niri;
    # Niri's X11 support; the module doesn't install it.
    environment.systemPackages = lib.mkIf cfg.niri [ pkgs.xwayland-satellite ];

    # Hyprland — primary/daily driver. Session env / noctalia startup driven by
    # hyprSessionBootstrap in home/dotfiles.nix (the bare target raced noctalia).
    programs.hyprland = {
      enable = true;
      # false alone doesn't drop the duplicate session entry — the package ships
      # hyprland-uwsm.desktop itself; the symlinkJoin strips that one file.
      withUWSM = false;
      # The module calls .override on the package, so the wrapper re-exposes it
      # (re-stripping after any override) plus the attrs the module reads.
      package =
        let
          stripUwsmSession =
            hl:
            pkgs.symlinkJoin {
              name = "hyprland-single-session";
              paths = [ hl ];
              # Also send Hyprland's console output (startup banner) to the journal:
              # greetd runs the session on the visible VT, so it flashed on login.
              postBuild = ''
                rm $out/share/wayland-sessions/hyprland-uwsm.desktop
                rm $out/share/wayland-sessions/hyprland.desktop
                sed 's|^Exec=|Exec=${pkgs.systemd}/bin/systemd-cat -t hyprland |' \
                  ${hl}/share/wayland-sessions/hyprland.desktop > $out/share/wayland-sessions/hyprland.desktop
              '';
              inherit (hl) version meta;
              passthru = hl.passthru or { } // {
                inherit (hl) man;
                providedSessions = [ "hyprland" ];
                override = args: stripUwsmSession (hl.override args);
              };
            };
        in
        stripUwsmSession pkgs.hyprland;
    };

    # ── Display Manager ───────────────────────────────────────────────────────────
    # Noctalia Greeter on greetd; `noctalia msg greeter-sync` copies wallpaper,
    # colours and monitor layout from the running shell.
    services.displayManager.noctalia-greeter = {
      enable = true;
      passwordlessSyncUsers = [ "gav" ];
      cursorTheme = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
      };
    };
    # greetd doesn't set XDG_DATA_DIRS, which is where the greeter looks for sessions.
    services.greetd.settings.default_session.command = lib.mkForce "env XDG_DATA_DIRS=${config.services.displayManager.sessionData.desktops}/share ${lib.getExe' config.services.displayManager.noctalia-greeter.package "noctalia-greeter-session"}";

    # Fallback preselection only (the greeter remembers last-used); Hyprland is
    # the daily driver.
    services.displayManager.defaultSession = "hyprland";

    # ── XDG Portals ───────────────────────────────────────────────────────────────
    # Each compositor module registers its own backends; only the shared fallback here.
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ]; # file dialogs everywhere
      config = {
        common.default = [ "gtk" ];
      };
    };

    # ── upower ────────────────────────────────────────────────────────────────────
    # Required by Noctalia for the battery widget
    services.upower.enable = true;

    # ── Polkit ────────────────────────────────────────────────────────────────────
    security.polkit.enable = true;

    # ── GNOME Keyring ─────────────────────────────────────────────────────────────
    # Its PAM hook lands in `login`, which greetd's PAM includes, so it unlocks at the greeter.
    services.gnome.gnome-keyring.enable = true;
    # Hyprland isn't started by systemd, so it never sees gcr-ssh-agent's
    # SSH_AUTH_SOCK in the user manager; export it at login instead.
    environment.extraInit = ''
      if [ -z "$SSH_AUTH_SOCK" ] && [ -n "$XDG_RUNTIME_DIR" ]; then
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
      fi
    '';

    # ── Fonts ─────────────────────────────────────────────────────────────────────
    fonts = {
      enableDefaultPackages = true;
      packages = with pkgs; [
        noto-fonts
        noto-fonts-cjk-sans # was noto-fonts-cjk
        noto-fonts-color-emoji # top-level noto-fonts-emoji became a throw alias 2025-10-27
        dejavu_fonts # was ttf-dejavu
        liberation_ttf # was ttf-liberation
        open-sans # was ttf-opensans
        ttf-bitstream-vera
        nerd-fonts.meslo-lg # was ttf-meslo-nerd; kept as fallback
        nerd-fonts.jetbrains-mono
      ];
      fontconfig.defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "JetBrainsMono Nerd Font Mono" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
