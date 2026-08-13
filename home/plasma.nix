# KDE Plasma via plasma-manager: appearance, panel removal (Noctalia is the
# bar), Polonium tiling, and the 3-tier shortcuts matching the other WMs.
{ config, lib, pkgs, ... }:

{
  programs.plasma = {
    enable = true;

    # ── Appearance ──────────────────────────────────────────────────────────────
    # Noctalia writes the "noctalia" color scheme at runtime; until its first
    # run Plasma falls back to Breeze and picks the scheme up on next login.
    workspace = {
      colorScheme = "noctalia";
      cursor = {
        theme = "Bibata-Modern-Ice";
        size  = 24;
      };
      iconTheme = "Papirus-Dark";
      # Match noctalia's current wallpaper so clicking the desktop shows the same image.
      wallpaper = "/home/gav/Pictures/backgrounds/abstract/a_painting_of_a_man_with_a_dripping_face.jpg";
    };

    # ── Panel removal ────────────────────────────────────────────────────────────
    # Noctalia is the bar. panels = [] is a no-op in plasma-manager, so removal
    # goes via the Plasma JS API; plasmashell persists the state across logins.
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
      "zen-private" = {
        name    = "Zen Private Window";
        key     = "Meta+Shift+Alt+B";
        command = "zen-beta --private-window";
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

      effects = {
        desktopSwitching = {
          animation          = "slide";
          navigationWrapping = true;
        };
        # Dim unfocused windows → active window stands out without needing a colored outline.
        dimInactive.enable = true;
        # Background blur: lets ghostty's 0.7 background-opacity actually look blurred.
        blur.enable = true;
      };
    };

    # ── Raw kwinrc overrides ─────────────────────────────────────────────────────
    configFile."kwinrc" = {
      Windows.PerOutputVirtualDesktops = true;
      MouseBindings.CommandAllKey   = "Meta";
      # "Previous/Next Desktop" here drags the focused window along — Nothing
      # stops windows following the scroll (Meta+Ctrl+Left/Right for desktop nav).
      MouseBindings.CommandAllWheel = "Nothing";

      # Focus follows mouse: hovering over a window focuses it, matching Hyprland/Niri defaults.
      Windows.FocusPolicy = "FocusFollowsMouse";

      # Breeze decoration border: shows a thin colored border on all four sides.
      # Active window gets noctalia's accent color; inactive is dimmed by dimInactive.
      "org.kde.kdecoration2".BorderSize     = "Normal";
      "org.kde.kdecoration2".BorderSizeAuto = false;

      # dimInactive strength: 0–100. 40 dims unfocused windows noticeably.
      "Effect-DimInactive".Strength = 40;
    };

    # Mouse acceleration profile: flat = 1:1 raw input, no accel curve.
    # Matches ~/.config/kcminputrc key already set live; declared here so it survives rebuilds.
    configFile."kcminputrc".Mouse.X11LibInputXAccelProfileFlat = true;

    # ── VRR / G-Sync ─────────────────────────────────────────────────────────
    # No plasma-manager option (lives in kscreen2, not kwinrc): enable once in
    # System Settings → Display; KWin persists it in ~/.local/share/kscreen/.

    # ── KWin window opacity rules ─────────────────────────────────────────────
    # Match niri/mango: focused=0.95 unfocused=0.85. Ghostty excluded — its
    # opacity is set in ghostty/config directly.
    configFile."kwinrulesrc" = {
      General.rules = "signal-opacity,vesktop-opacity,zen-opacity,obsidian-opacity";

      "signal-opacity" = {
        Description          = "Signal transparency";
        wmclass              = "signal";
        wmclassmatch         = 3;
        opacityactive        = 95;
        opacityactiverule    = 2;
        opacityinactive      = 85;
        opacityinactiverule  = 2;
      };

      "vesktop-opacity" = {
        Description          = "Vesktop transparency";
        wmclass              = "vesktop";
        wmclassmatch         = 3;
        opacityactive        = 95;
        opacityactiverule    = 2;
        opacityinactive      = 85;
        opacityinactiverule  = 2;
      };

      "zen-opacity" = {
        Description          = "Zen Browser transparency";
        wmclass              = "zen";
        wmclassmatch         = 3;
        opacityactive        = 95;
        opacityactiverule    = 2;
        opacityinactive      = 85;
        opacityinactiverule  = 2;
      };

      "obsidian-opacity" = {
        Description          = "Obsidian transparency";
        wmclass              = "obsidian";
        wmclassmatch         = 3;
        opacityactive        = 95;
        opacityactiverule    = 2;
        opacityinactive      = 85;
        opacityinactiverule  = 2;
      };
    };

    # ── 3-tier KWin shortcuts ────────────────────────────────────────────────────
    shortcuts.kwin = {
      # ── SUPER — focus / window state ─────────────────────────────────────────
      # Switch Window * cleared so Polonium (tiling-aware) owns Meta+H/J/K/L —
      # both registering Meta+H made focus navigation unreliable.
      "Switch Window Left"  = "none";
      "Switch Window Down"  = "none";
      "Switch Window Up"    = "none";
      "Switch Window Right" = "none";
      "Window Close"        = "Meta+Q";
      "Window Maximize"     = "Meta+F";
      "Window Minimize"     = "Meta+W";

      # ── SUPER+SHIFT — move window within tiling layout ───────────────────────
      # Polonium's Place* own Meta+Shift+H/J/K/L; quick-tile cleared to match.
      "Window Quick Tile Left"   = "none";
      "Window Quick Tile Bottom" = "none";
      "Window Quick Tile Top"    = "none";
      "Window Quick Tile Right"  = "none";

      # ── SUPER — desktop jump ─────────────────────────────────────────────────
      # Matches niri/hyprland/mango: bare Mod+N jumps straight to desktop N.
      "Switch to Desktop 1" = "Meta+1";
      "Switch to Desktop 2" = "Meta+2";
      "Switch to Desktop 3" = "Meta+3";
      "Switch to Desktop 4" = "Meta+4";
      "Switch to Desktop 5" = "Meta+5";
      "Switch to Desktop 6" = "Meta+6";

      # ── SUPER+CTRL — move window to desktop N / adjacent desktop / monitor nav ─
      # Matches niri/hyprland/mango: Mod+Ctrl+N sends the window to desktop N.
      "Window to Desktop 1" = "Meta+Ctrl+1";
      "Window to Desktop 2" = "Meta+Ctrl+2";
      "Window to Desktop 3" = "Meta+Ctrl+3";
      "Window to Desktop 4" = "Meta+Ctrl+4";
      "Window to Desktop 5" = "Meta+Ctrl+5";
      "Window to Desktop 6" = "Meta+Ctrl+6";
      # Desktop grid is rows=1 (flat 6-across), so "Up/Down" grid actions are
      # meaningless — bind the Up/Down keys to the Left/Right actions instead,
      # matching the Up/Down keystroke niri/hyprland/mango use for adjacent-cycle.
      "Switch One Desktop to the Left"  = "Meta+Ctrl+Up";
      "Switch One Desktop to the Right" = "Meta+Ctrl+Down";
      "Switch to Next Screen"     = "Meta+Ctrl+.";
      "Switch to Previous Screen" = "Meta+Ctrl+,";

      # ── SUPER+CTRL+ALT — move window to adjacent desktop / monitor ────────────
      "Window One Desktop to the Left"  = "Meta+Ctrl+Alt+Up";
      "Window One Desktop to the Right" = "Meta+Ctrl+Alt+Down";
      "Window to Next Screen"      = "Meta+Ctrl+Alt+.";
      "Window to Previous Screen"  = "Meta+Ctrl+Alt+,";
    };
  };
}
