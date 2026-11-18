# The desktop: login screen, Hyprland (plus Mango and Niri, switched off),
# file dialogs, keyring and fonts.
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
  options.gav.sessions = {
    mango = lib.mkEnableOption "the Mango session";
    niri = lib.mkEnableOption "the niri session";
  };

  config = {
    # --- Which desktops are on ---
    # Set one to true to get it back on the login screen. Hyprland is always on.
    gav.sessions = {
      mango = false;
      niri = false;
    };

    # --- Mango and Niri ---
    programs.mango.enable = cfg.mango;
    # Mango's session target isn't linked by its module.
    systemd.packages = lib.mkIf cfg.mango [ config.programs.mango.package ];

    programs.niri.enable = cfg.niri;
    # Niri needs this to run X11 apps.
    environment.systemPackages = lib.mkIf cfg.niri [ pkgs.xwayland-satellite ];

    # --- Hyprland ---
    # Started through the session start script in home/desktop/dotfiles.nix.
    programs.hyprland = {
      enable = true;
      withUWSM = false;
      # Wrapped to leave one Hyprland entry on the login screen (the package
      # ships a second one) and to send its startup text to the journal.
      package =
        let
          stripUwsmSession =
            hl:
            pkgs.symlinkJoin {
              name = "hyprland-single-session";
              paths = [ hl ];
              postBuild = ''
                rm $out/share/wayland-sessions/hyprland-uwsm.desktop
                rm $out/share/wayland-sessions/hyprland.desktop
                sed 's|^Exec=|Exec=${pkgs.systemd}/bin/systemd-cat -t hyprland |' \
                  ${hl}/share/wayland-sessions/hyprland.desktop > $out/share/wayland-sessions/hyprland.desktop
              '';
              inherit (hl) version meta;
              # The Hyprland module overrides the package, so pass that through.
              passthru = hl.passthru or { } // {
                inherit (hl) man;
                providedSessions = [ "hyprland" ];
                override = args: stripUwsmSession (hl.override args);
              };
            };
        in
        stripUwsmSession pkgs.hyprland;
    };

    # --- Login screen ---
    # Noctalia Greeter. `noctalia msg greeter-sync` copies over the wallpaper,
    # colors and monitor layout.
    services.displayManager.noctalia-greeter = {
      enable = true;
      passwordlessSyncUsers = [ "gav" ];
      cursorTheme = {
        package = pkgs.bibata-cursors;
        name = "Bibata-Modern-Ice";
      };
    };
    # Tells the greeter where the list of sessions is.
    services.greetd.settings.default_session.command =
      lib.mkForce "env XDG_DATA_DIRS=${config.services.displayManager.sessionData.desktops}/share ${lib.getExe' config.services.displayManager.noctalia-greeter.package "noctalia-greeter-session"}";

    # Only matters the first time; the greeter remembers the last one used.
    services.displayManager.defaultSession = "hyprland";

    # --- File dialogs and screen sharing (portals) ---
    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = [ "gtk" ];
    };

    services.upower.enable = true; # Noctalia's battery widget
    security.polkit.enable = true;

    # --- Keyring ---
    # Unlocks with my password at the login screen.
    services.gnome.gnome-keyring.enable = true;
    # Points Hyprland's apps at the keyring's SSH agent.
    environment.extraInit = ''
      if [ -z "$SSH_AUTH_SOCK" ] && [ -n "$XDG_RUNTIME_DIR" ]; then
        export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
      fi
    '';

    # --- Fonts ---
    fonts = {
      enableDefaultPackages = true;
      packages =
        with pkgs;
        [
          noto-fonts
          noto-fonts-cjk-sans
          noto-fonts-color-emoji
          dejavu_fonts
          liberation_ttf
          open-sans
          ttf-bitstream-vera
        ]
        # Coding fonts for the `font` picker.
        ++ map (f: f.package) (import ../../home/theming/font-list.nix pkgs);
      fontconfig.defaultFonts = {
        serif = [ "Noto Serif" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "JetBrainsMono Nerd Font Mono" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };
}
