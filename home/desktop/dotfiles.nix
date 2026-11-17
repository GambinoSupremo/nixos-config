# Copies my dotfiles repo into ~/.config, with a few changes NixOS needs.
# Each change checks its target line is still there, or the build fails.
{
  pkgs,
  lib,
  inputs,
  host,
  osConfig,
  ...
}:

let
  inherit (host) isVM;
  sessions = osConfig.gav.sessions; # which desktops are on (nixos/base/desktop.nix)
  configDirs = [
    "hypr"
    "ghostty"
  ]
  ++ lib.optional sessions.mango "mango"
  ++ lib.optional sessions.niri "niri";

  # --- Session start scripts ---
  # Hand the display settings to systemd, then restart what depends on them.
  mangoSessionBootstrap = pkgs.writeShellScript "mango-session-bootstrap" ''
    systemctl --user unset-environment HYPRLAND_INSTANCE_SIGNATURE
    systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE MANGO_INSTANCE_SIGNATURE
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP MANGO_INSTANCE_SIGNATURE
    systemctl --user reset-failed
    systemctl --user restart noctalia.service
    # Sunshine needs the compositor env for wlr screen capture.
    systemctl --user restart sunshine.service
    ${lib.optionalString (!isVM) "systemctl --user start --no-block battlenet-background.service"}
  '';

  hyprSessionBootstrap = pkgs.writeShellScript "hypr-session-bootstrap" ''
    systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE HYPRLAND_INSTANCE_SIGNATURE
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE
    systemctl --user reset-failed
    systemctl --user restart noctalia.service
    # Sunshine needs the compositor env for wlr screen capture.
    systemctl --user restart sunshine.service
    ${lib.optionalString (!isVM) "systemctl --user start --no-block battlenet-background.service"}
  '';

  # --- Hyprland fallback ---
  # Bare-bones hyprland.conf, only used if hyprland.lua fails to load.
  # The "\n" is there because Nix drops a leading blank line.
  hyprFallbackConf = pkgs.writeText "hyprland.conf" (
    "\n"
    + ''
      source = optional:/home/gav/.config/hypr/noctalia/noctalia-colors.conf

      # ── NixOS additions ─────────────────────────────────────────────────────────
      # Minimal fallback so the session is never a dead end if hyprland.lua fails.
      # Matched by EDID description (connector names renumber); wildcard catch-all.
      monitor = desc:Dell Inc. Dell AW3423DW #tBszGDAYBQUH, 3440x1440@174, 0x0, 1
      monitor = desc:Philips Consumer Electronics Company PHL 278E1 0x0000065F, 3840x2160@60, 3440x0, 1.5
      monitor = , preferred, auto, 1
      misc {
          vrr = 0    # off: stutters on the RX 9070 XT, same as hyprland.lua
      }
      exec-once = systemctl --user start noctalia.service
      exec-once = sleep 5 && mullvad-exclude vesktop
      bind = SUPER, Return, exec, ghostty
      bind = SUPER, Q, killactive
      bind = SUPER SHIFT, E, exit
      bind = SUPER SHIFT, D, exec, mullvad-exclude vesktop
      bind = SUPER, code:51, exec, noctalia msg panel-toggle control-center audio
      # Per-app opacity, same values as niri
      windowrule = match:class ^(signal)$, opacity 0.95 0.90
      windowrule = match:class ^(vesktop)$, opacity 0.95 0.90
      windowrule = match:class ^(obsidian)$, opacity 0.95 0.90
    ''
  );

  # --- The patched copy ---
  # Files Noctalia rewrites are left out here; noctalia.nix copies those in.
  dotfiles = pkgs.runCommandLocal "dotfiles-patched" { } ''
    mkdir -p $out
    for d in ${lib.concatStringsSep " " configDirs}; do
      cp -r ${inputs.dotfiles}/$d $out/$d
    done
    chmod -R u+w $out

    # mustSed <file> <line to find> <change>: stop the build if the line is gone.
    mustSed() {
      grep -q -e "$2" "$1" || {
        echo "dotfiles patch FAILED: pattern not found in $1: $2" >&2
        exit 1
      }
      sed -i -e "$3" "$1"
    }

    ${lib.optionalString sessions.mango ''
      # Mango: use the session start script.
      mustSed $out/mango/autostart.conf \
        '^exec_once=systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP MANGO_INSTANCE_SIGNATURE$' \
        's|^exec_once=systemctl --user import-environment .*$|exec_once=${mangoSessionBootstrap}|'
      rm $out/mango/noctalia.conf
      # Mango cuts config lines off at 255 characters without warning.
      if grep -rn '.\{256,\}' $out/mango; then
        echo "dotfiles patch FAILED: mango config line over 255 chars" >&2
        exit 1
      fi
    ''}

    # Hyprland: add the fallback config and use the session start script.
    cp ${hyprFallbackConf} $out/hypr/hyprland.conf
    mustSed $out/hypr/autostart.lua \
      'hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")' \
      's|hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")|hl.exec_cmd("${hyprSessionBootstrap}")|'
    mustSed $out/hypr/autostart.lua \
      'hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")' \
      '/hl.exec_cmd("systemctl --user import-environment DISPLAY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")/d'

    # Files Noctalia rewrites (noctalia.nix copies them in instead).
    ${lib.optionalString sessions.niri "rm $out/niri/noctalia.kdl"}
    rm $out/ghostty/themes/noctalia

    # No commands from the old Noctalia v4 may be left.
    if grep -rn 'qs -c\|noctalia-shell ipc' $out; then
      echo "dotfiles patch FAILED: v4 Noctalia references remain (see above)" >&2
      exit 1
    fi
  '';

  # recursive: folders stay writable. force: replace whatever was there before.
  deploy = dir: {
    source = "${dotfiles}/${dir}";
    recursive = true;
    force = true;
  };
  hidden = {
    force = true;
    text = "[Desktop Entry]\nHidden=true\n";
  };
in
{
  xdg.configFile = {
    # --- Into ~/.config ---
    "hypr" = deploy "hypr";
    "ghostty" = deploy "ghostty";
    "mango" = lib.mkIf sessions.mango (deploy "mango");
    "niri" = lib.mkIf sessions.niri (deploy "niri");

    # --- Autostart entries switched off ---
    # Mullvad starts from its own service (vpn-bluetooth.nix). Signal and
    # Vesktop start from the desktop config; two Signals at login lock its database.
    "autostart/mullvad-vpn.desktop" = hidden;
    "autostart/signal.desktop" = hidden;
    "autostart/vesktop.desktop" = hidden;
  };
}
