# KineticWE defaults mirroring Hyprland: seeded once by ~/.config/kineticwe/pre-start
# (run by the session launcher), then owned by Kinetic Settings.
{ lib, pkgs, ... }:

let
  kwc = "${pkgs.kdePackages.kconfig}/bin/kwriteconfig6";

  shotClip = pkgs.writeShellScript "kwe-shot-clip" ''
    exec ${pkgs.kdePackages.spectacle}/bin/spectacle -r -b -n -c
  '';
  shotFile = pkgs.writeShellScript "kwe-shot-file" ''
    mkdir -p "$HOME/Pictures/Screenshots"
    exec ${pkgs.kdePackages.spectacle}/bin/spectacle -r -b -n -o "$HOME/Pictures/Screenshots/$(date +%s).png"
  '';

  # Spawn binds, launched by kglobalaccel as actions of one hidden .desktop file.
  commands = {
    terminal         = { name = "Terminal";              key = "Meta+Return";         exec = "ghostty"; };
    terminal-float   = { name = "Floating terminal";     key = "Meta+Ctrl+Return";    exec = "ghostty --gtk-single-instance=false --class=com.ghostty.floating"; };
    browser          = { name = "Browser";               key = "Meta+Shift+B";        exec = "zen-beta"; };
    browser-private  = { name = "Private browser";       key = "Meta+Alt+Shift+B";    exec = "zen-beta --private-window"; };
    files            = { name = "Files";                 key = "Meta+Shift+E";        exec = "nautilus"; };
    discord          = { name = "Discord";               key = "Meta+Shift+D";        exec = "mullvad-exclude vesktop"; };
    obsidian         = { name = "Obsidian";              key = "Meta+Shift+O";        exec = "obsidian"; };
    music            = { name = "Music";                 key = "Meta+Shift+M";        exec = "tidal-hifi"; };
    editor           = { name = "Editor";                key = "Meta+Shift+Z";        exec = "zeditor"; };
    audio-panel      = { name = "Audio panel";           key = "Meta+\\";             exec = "noctalia-kwe msg panel-toggle control-center audio"; };
    emoji            = { name = "Emoji picker";          key = "Meta+Alt+E";          exec = "noctalia-kwe msg panel-open launcher /emo"; };
    restart-noctalia = { name = "Restart noctalia";      key = "Meta+Alt+R";          exec = "pkill -f '/bin/noctalia$'"; };
    kinetic-settings = { name = "Kinetic Settings";      key = "Meta+I";              exec = "noctalia-kwe msg kinetic-settings-toggle"; };
    shot-clip        = { name = "Screenshot to clipboard"; key = "Alt+Shift+S";       exec = "${shotClip}"; };
    shot-file        = { name = "Screenshot to file";    key = "Meta+Shift+S";        exec = "${shotFile}"; };
    play-pause       = { name = "Play/pause";            key = "Media Play";          exec = "playerctl play-pause"; };
    next-track       = { name = "Next track";            key = "Media Next";          exec = "playerctl next"; };
    prev-track       = { name = "Previous track";        key = "Media Previous";      exec = "playerctl previous"; };
    vol-up           = { name = "Volume up";             key = "Volume Up";           exec = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"; };
    vol-down         = { name = "Volume down";           key = "Volume Down";         exec = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"; };
    vol-mute         = { name = "Mute";                  key = "Volume Mute";         exec = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"; };
  };

  # Built-in actions: [] clears a KineticWE default that collides with these binds.
  kwinShortcuts = {
    "Window Close"          = [ "Meta+Q" ];
    "Noctalia Launcher"     = [ "Meta+Space" ];
    # Stock directional focus crosses monitors; Tiling Focus can't, so it's cleared.
    "Switch Window Left"    = [ "Meta+Left"  "Meta+H" ];
    "Switch Window Right"   = [ "Meta+Right" "Meta+L" ];
    "Switch Window Up"      = [ "Meta+Up"    "Meta+K" ];
    "Switch Window Down"    = [ "Meta+Down"  "Meta+J" ];
    "Tiling Focus Left"     = [ ];
    "Tiling Focus Right"    = [ ];
    "Tiling Focus Up"       = [ ];
    "Tiling Focus Down"     = [ ];
    "Swap Tiled Window Left"  = [ "Meta+Shift+Left"  "Meta+Shift+H" ];
    "Swap Tiled Window Right" = [ "Meta+Shift+Right" "Meta+Shift+L" ];
    "Swap Tiled Window Up"    = [ "Meta+Shift+Up"    "Meta+Shift+K" ];
    "Swap Tiled Window Down"  = [ "Meta+Shift+Down"  "Meta+Shift+J" ];
    "Switch to Screen to the Left"  = [ "Meta+Ctrl+Left"  "Meta+Ctrl+H" ];
    "Switch to Screen to the Right" = [ "Meta+Ctrl+Right" "Meta+Ctrl+L" ];
    # One desktop row: Up/Down keys drive the Left/Right actions.
    "Switch One Desktop to the Left"  = [ "Meta+Ctrl+Up"   "Meta+Ctrl+K" ];
    "Switch One Desktop to the Right" = [ "Meta+Ctrl+Down" "Meta+Ctrl+J" ];
    "Switch One Desktop Up"   = [ ];
    "Switch One Desktop Down" = [ ];
    "Tiling Move Window Left Output"  = [ "Meta+Ctrl+Alt+Left"  "Meta+Ctrl+Alt+H" ];
    "Tiling Move Window Right Output" = [ "Meta+Ctrl+Alt+Right" "Meta+Ctrl+Alt+L" ];
    "Window One Desktop to the Left"  = [ "Meta+Ctrl+Alt+Up"   "Meta+Ctrl+Alt+K" ];
    "Window One Desktop to the Right" = [ "Meta+Ctrl+Alt+Down" "Meta+Ctrl+Alt+J" ];
    "Window One Desktop Up"   = [ ];
    "Window One Desktop Down" = [ ];
    "Tiling Toggle Floating"  = [ "Meta+W" ];
    "Window Fullscreen"       = [ "Meta+F" ];
    "Window Maximize"         = [ "Meta+M" ];
    "Window On All Desktops"  = [ "Meta+Shift+G" ];
    "Window Grow Horizontal"   = [ "Meta+=" ];
    "Window Shrink Horizontal" = [ "Meta+-" ];
    "Window Grow Vertical"     = [ "Meta++" ];
    "Window Shrink Vertical"   = [ "Meta+_" ];
    "view_zoom_in"  = [ ];
    "view_zoom_out" = [ ];
  } // lib.listToAttrs (lib.concatMap (i: [
    (lib.nameValuePair "Switch to Desktop ${toString i}" [ "Meta+${toString i}" ])
    (lib.nameValuePair "Window to Desktop ${toString i}" [ "Meta+Ctrl+${toString i}" ])
  ]) (lib.range 1 6));

  noctaliaShortcuts = {
    NoctaliaToggleSessionMenu     = [ "Meta+Esc" ];
    NoctaliaToggleWallpaperPicker = [ "Meta+Alt+W" ];
    NoctaliaToggleClipboard       = [ "Meta+Ctrl+V" ];
    NoctaliaWindowSwitcher        = [ "Alt+Tab" ];
  };

  # Component entries are "keys,default,name"; services (.desktop) entries are bare keys.
  shortcutLine = groups: action: keys:
    let
      active = if keys == [ ] then "none" else lib.concatStringsSep "\t" keys;
      value  = if lib.head groups == "services" then active else "${active},,${action}";
    in "${kwc} --file \"$kcfg/kglobalshortcutsrc\" ${lib.concatMapStringsSep " " (g: "--group ${lib.escapeShellArg g}") groups} --key ${lib.escapeShellArg action} ${lib.escapeShellArg value}";

  setIn = file: groups: key: value:
    "${kwc} --file \"$kcfg/${file}\" ${lib.concatMapStringsSep " " (g: "--group ${lib.escapeShellArg g}") groups} --key ${lib.escapeShellArg key} ${lib.escapeShellArg (toString value)}";
  set = file: group: setIn file [ group ];

  # screen 0 = DP-1 (4K), 1 = DP-2 (Alienware). *match 3 = regex; *rule 2 = force,
  # 3 = initially. desktops/screen are forced: the screen move resets initial desktops.
  opacity = cls: { wmclass = cls; wmclassmatch = 3;
    opacityactive = 95; opacityactiverule = 2; opacityinactive = 85; opacityinactiverule = 2; };
  windowRules = {
    # Steam + games → desktop 2 on the Alienware, no focus stealing.
    steam = { wmclass = "^(steam|steam_app_.*)$"; wmclassmatch = 3;
      desktops = "Desktop_2"; desktopsrule = 2; screen = 1; screenrule = 2;
      fsplevel = 4; fsplevelrule = 2; };
    comms = { wmclass = "^(vesktop|signal|Signal|tidal-hifi|TIDAL HiFi)$"; wmclassmatch = 3;
      desktops = "Desktop_2"; desktopsrule = 2; screen = 0; screenrule = 3; };
    ghostty-floating = { wmclass = "^com\\.ghostty\\.floating$"; wmclassmatch = 3;
      size = "900,600"; sizerule = 3; };
    # Match niri: focused 0.95, unfocused 0.85 (ghostty sets its own).
    signal-opacity   = opacity "signal";
    vesktop-opacity  = opacity "vesktop";
    zen-opacity      = opacity "zen";
    obsidian-opacity = opacity "obsidian";
  };
  ruleLines = lib.concatLists (lib.mapAttrsToList (id: props:
    [ (set "rules.kwe" id "Description" id) ]
    ++ lib.mapAttrsToList (k: v: set "rules.kwe" id k v) props) windowRules);

  # Hyprland: gaps_in 5 (per side → 10 between) / gaps_out 10, border 2, rounding 6.
  tiling = {
    Enabled = "true";
    DefaultLayout = "MasterStack";
    GapBetween = 10; GapLeft = 10; GapRight = 10; GapTop = 10; GapBottom = 10;
    TilingBorderMode = "AllWindows";
    TilingBorderThickness = 2;
    TilingCornerRadius = 6;
    TilingBorderColorSourceActive = "NoctaliaPrimary";
  };
  # Closest to Hyprland's ws2 (full-width, Steam) and ws3 (scrolling).
  desktopLayouts = { "2:DP-2" = "Monocle"; "3:DP-2" = "Columns"; };

  # Bump to re-apply all defaults (overwrites Kinetic Settings changes) next login.
  seedVersion = "3";

  preStart = pkgs.writeShellScript "kineticwe-pre-start" ''
    set -u
    cfg="''${XDG_CONFIG_HOME:-$HOME/.config}"
    # 2.0 compositor config lives in ~/.config/kineticwe.
    kcfg="''${KWE_CONFIG_HOME:-$cfg/kineticwe}"
    marker="$kcfg/.seeded-v${seedVersion}"
    # One-time fixes for configs seeded before 2026-09-24 (each has a marker file).
    # 2.0 renamed the shortcut component kwin → kineticwe; comms → desktop 2.
    mig="$kcfg/.migrated-kwe2-component"
    if [ -e "$marker" ] && [ ! -e "$mig" ]; then
      ${lib.concatStringsSep "\n      " (lib.mapAttrsToList (a: k: shortcutLine [ "kineticwe" ] a k) kwinShortcuts)}
      ${set "rules.kwe" "comms" "desktops" "Desktop_2"}
      touch "$mig"
    fi
    if [ -e "$marker" ] && [ ! -e "$kcfg/.migrated-force-desktops" ]; then
      ${set "rules.kwe" "steam" "desktopsrule" 2}
      ${set "rules.kwe" "comms" "desktopsrule" 2}
      touch "$kcfg/.migrated-force-desktops"
    fi
    # 2.0 generated random desktop ids; "Desktop_2" matched nothing (→ all desktops).
    if [ -e "$marker" ] && [ ! -e "$kcfg/.migrated-desktop-ids" ]; then
      d2=$(${pkgs.kdePackages.kconfig}/bin/kreadconfig6 --file "$kcfg/kineticwe.kwe" --group Desktops --key Id_2)
      if [ -n "$d2" ]; then
        ${kwc} --file "$kcfg/rules.kwe" --group steam --key desktops "$d2"
        ${kwc} --file "$kcfg/rules.kwe" --group comms --key desktops "$d2"
      fi
      touch "$kcfg/.migrated-desktop-ids"
    fi
    # Game launcher windows skipped the initial screen rule.
    if [ -e "$marker" ] && [ ! -e "$kcfg/.migrated-steam-screen-force" ]; then
      ${set "rules.kwe" "steam" "screenrule" 2}
      touch "$kcfg/.migrated-steam-screen-force"
    fi
    [ -e "$marker" ] && exit 0
    mkdir -p "$kcfg"
    # Seed once from scratch; unset actions fall back to KineticWE's defaults.
    rm -f "$kcfg/kglobalshortcutsrc" "$kcfg/rules.kwe"

    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (a: k: shortcutLine [ "kineticwe" ] a k) kwinShortcuts)}
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (a: k: shortcutLine [ "noctalia" ] a k) noctaliaShortcuts)}
    ${shortcutLine [ "ksmserver" ] "Lock Session" [ "Screensaver" ]}
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (id: c: shortcutLine [ "services" "kineticwe-commands.desktop" ] id [ c.key ]) commands)}

    ${set "kineticwe.kwe" "Windows" "FocusPolicy" "FocusFollowsMouse"}
    ${set "kineticwe.kwe" "MouseBindings" "CommandAllKey" "Meta"}
    ${set "kineticwe.kwe" "MouseBindings" "CommandAllWheel" "Nothing"}
    ${set "kineticwe.kwe" "Desktops" "Number" 6}
    ${set "kineticwe.kwe" "Desktops" "Rows" 1}
    ${lib.concatMapStringsSep "\n    " (i: set "kineticwe.kwe" "Desktops" "Id_${toString i}" "Desktop_${toString i}") (lib.range 1 6)}
    ${set "kineticwe.kwe" "Mouse" "X11LibInputXAccelProfileFlat" "true"}
    ${set "kineticwe.kwe" "Mouse" "cursorTheme" "Bibata-Modern-Ice"}
    ${set "kineticwe.kwe" "Mouse" "cursorSize" 24}
    ${set "kineticwe.kwe" "Windows" "PerOutputVirtualDesktops" "true"}
    # Meta+scroll = switch desktop only (default drags the window along).
    ${set "kineticwe.kwe" "Windows" "InvertScrollDesktopSwitch" "true"}
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: set "kineticwe.kwe" "Tiling" k v) tiling)}
    ${lib.concatStringsSep "\n" (lib.mapAttrsToList (d: l: setIn "kineticwe.kwe" [ "Tiling" "DesktopOutput ${d}" ] "DefaultLayout" l) desktopLayouts)}
    ${set "kineticwe.kwe" "TilingRules" "FloatingClass" "com.ghostty.floating"}

    # Inactive border = noctalia "surface" (as Hyprland), read from its Hyprland palette.
    surf=$(sed -n 's/^local surface = "rgb(\([0-9a-fA-F]\{6\}\))"$/\1/p' "$cfg/hypr/noctalia.lua" 2>/dev/null)
    if [ -n "$surf" ]; then
      ${set "kineticwe.kwe" "Tiling" "TilingBorderColorSourceInactive" "Custom"}
      ${kwc} --file "$kcfg/kineticwe.kwe" --group Tiling --key TilingBorderColorInactive \
        "$(printf '%d,%d,%d' 0x''${surf:0:2} 0x''${surf:2:2} 0x''${surf:4:2})"
    else
      ${set "kineticwe.kwe" "Tiling" "TilingBorderColorSourceInactive" "SystemAccentFaded"}
    fi

    ${set "rules.kwe" "General" "rules" (lib.concatStringsSep "," (lib.attrNames windowRules))}
    ${set "rules.kwe" "General" "count" (builtins.length (lib.attrNames windowRules))}
    ${lib.concatStringsSep "\n" ruleLines}

    mkdir -p "$(dirname "$marker")" && touch "$marker"
  '';
in
{
  home.packages = [ pkgs.kdePackages.spectacle ];

  xdg.desktopEntries.kineticwe-commands = {
    name      = "KineticWE Commands";
    noDisplay = true;
    exec      = "true";
    # Scripts avoid Exec= escaping; restore XDG_CONFIG_HOME (kwin's is ~/.config/kineticwe).
    actions   = lib.mapAttrs (id: c: {
      inherit (c) name;
      exec = "${pkgs.writeShellScript "kwe-${id}" ''
        export XDG_CONFIG_HOME="''${KWE_REAL_CONFIG_HOME:-$HOME/.config}"
        exec ${c.exec}
      ''}";
    }) commands;
  };

  xdg.configFile."kineticwe/pre-start" = {
    source     = preStart;
    executable = true;
  };
}
