{ config, lib, pkgs, ... }:

{
  programs.plasma = {
    enable = true;

    # ── Appearance ──────────────────────────────────────────────────────────────
    # colorScheme: Noctalia writes ~/.local/share/color-schemes/noctalia.colors
    # at runtime via its kcolorscheme builtin template. On a fresh system it
    # won't exist until noctalia.service has run once — Plasma falls back to
    # Breeze gracefully and picks up the scheme on next login.
    workspace = {
      colorScheme = "noctalia";
      cursor = {
        theme = "Bibata-Modern-Ice";
        size  = 24;
      };
      iconTheme = "Papirus-Dark";
    };

    # ── Panel removal ────────────────────────────────────────────────────────────
    # Noctalia is the bar. programs.plasma.panels = [] is a no-op in
    # plasma-manager (the panel desktop script only fires when panels is
    # non-empty), so removal is driven via the Plasma JS scripting API instead.
    # The script runs once per unique hash; plasmashell persists the "no panels"
    # state back to plasma-org.kde.plasma.desktop-appletsrc across logins.
    startup.desktopScript."remove-default-panels" = {
      text = ''
        var allPanels = panels();
        for (var i = 0; i < allPanels.length; i++) {
          allPanels[i].remove();
        }
      '';
    };

    # ── Terminal / launcher hotkeys ──────────────────────────────────────────────
    hotkeys.commands = {
      "launch-ghostty" = {
        name    = "Launch Ghostty";
        key     = "Meta+Return";
        command = "ghostty";
      };
      "noctalia-launcher" = {
        name    = "Noctalia Launcher";
        key     = "Meta+Space";
        command = "noctalia msg panel-toggle launcher";
      };
    };

    # ── KWin ─────────────────────────────────────────────────────────────────────
    kwin = {
      scripts.polonium = {
        enable = true;
        settings = {
          maximizeSingleWindow = true;
          layout.engine        = "binaryTree";
          tilePopups           = false;
        };
      };

      virtualDesktops = {
        names = [ "I" "II" "III" "IV" "V" "VI" ];   # implies number = 6
        rows  = 1;
      };

      effects.desktopSwitching = {
        animation          = "slide";
        navigationWrapping = true;   # kwinrc [Windows] RollOverDesktops
      };
    };

    # ── Raw kwinrc overrides ─────────────────────────────────────────────────────
    configFile."kwinrc" = {
      # Per-screen virtual desktops (KDE 6.7+ feature).
      # Key confirmed in src/kcms/desktop/virtualdesktopssettings.kcfg.
      Windows.PerOutputVirtualDesktops = true;

      # SUPER+scroll → previous/next virtual desktop.
      # CommandAllKey: modifier that activates the "All windows" mouse binding.
      # CommandAllWheel enum value confirmed in kwinoptions_settings.kcfg.
      MouseBindings.CommandAllKey   = "Meta";
      MouseBindings.CommandAllWheel = "Previous/Next Desktop";
    };

    # ── 3-tier KWin shortcuts ────────────────────────────────────────────────────
    shortcuts.kwin = {
      # ── SUPER — focus / window state ─────────────────────────────────────────
      "Switch Window Left"  = "Meta+H";
      "Switch Window Down"  = "Meta+J";
      "Switch Window Up"    = "Meta+K";
      "Switch Window Right" = "Meta+L";
      "Window Close"        = "Meta+Q";
      "Window Maximize"     = "Meta+F";
      "Window Minimize"     = "Meta+W";

      # ── SUPER+SHIFT — move window within workspace ────────────────────────────
      # KWin quick-tile (snap to edge) as the movement primitive for now.
      # Polonium swap shortcuts (group "polonium" in kglobalshortcutsrc) will be
      # added to shortcuts.polonium after first boot via rc2nix to get exact
      # action names; quick-tile and Polonium coexist without conflict.
      "Window Quick Tile Left"   = "Meta+Shift+H";
      "Window Quick Tile Bottom" = "Meta+Shift+J";
      "Window Quick Tile Top"    = "Meta+Shift+K";
      "Window Quick Tile Right"  = "Meta+Shift+L";

      # ── SUPER+CTRL — workspace / monitor navigation ───────────────────────────
      "Switch to Desktop 1" = "Meta+Ctrl+1";
      "Switch to Desktop 2" = "Meta+Ctrl+2";
      "Switch to Desktop 3" = "Meta+Ctrl+3";
      "Switch to Desktop 4" = "Meta+Ctrl+4";
      "Switch to Desktop 5" = "Meta+Ctrl+5";
      "Switch to Desktop 6" = "Meta+Ctrl+6";
      "Switch One Desktop to the Left"  = "Meta+Ctrl+Left";
      "Switch One Desktop to the Right" = "Meta+Ctrl+Right";
      "Switch to Next Screen"     = "Meta+Ctrl+.";
      "Switch to Previous Screen" = "Meta+Ctrl+,";

      # ── SUPER+CTRL+ALT — move windows across workspaces / monitors ────────────
      "Window to Desktop 1" = "Meta+Ctrl+Alt+1";
      "Window to Desktop 2" = "Meta+Ctrl+Alt+2";
      "Window to Desktop 3" = "Meta+Ctrl+Alt+3";
      "Window to Desktop 4" = "Meta+Ctrl+Alt+4";
      "Window to Desktop 5" = "Meta+Ctrl+Alt+5";
      "Window to Desktop 6" = "Meta+Ctrl+Alt+6";
      "Window to Previous Desktop" = "Meta+Ctrl+Alt+Left";
      "Window to Next Desktop"     = "Meta+Ctrl+Alt+Right";
      "Window to Next Screen"      = "Meta+Ctrl+Alt+.";
      "Window to Previous Screen"  = "Meta+Ctrl+Alt+,";
    };
  };
}
