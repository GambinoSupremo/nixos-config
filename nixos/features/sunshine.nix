# Sunshine (Moonlight streaming host). Each stream gets a headless virtual
# display at the client's resolution/refresh; physical monitors stay on.
{ pkgs, ... }:

let
  alienware = "Dell Inc. Dell AW3423DW #tBszGDAYBQUH";
  # Steam Controller puck (28de:1304): a controller paired to it grabs player 1 over Moonlight's pad.
  puck = state: ''
    for d in /sys/bus/usb/devices/*; do
      [ "$(cat "$d/idVendor" 2>/dev/null):$(cat "$d/idProduct" 2>/dev/null)" = 28de:1304 ] && echo ${state} > "$d/authorized"
    done
  '';
  watchPid = "$XDG_RUNTIME_DIR/sunshine-game-watch.pid";
  # Put ws 2 (Steam + games) on SUNSHINE at the client mode. Fullscreen windows can block the
  # move, so drop fullscreen first, retry until ws 2 actually lands, then re-fullscreen games.
  lendWs2 = pkgs.writeShellScript "sunshine-lend-ws2" ''
    jq=${pkgs.jq}/bin/jq
    hyprctl eval "hl.monitor({ output = \"SUNSHINE\", mode = \"''${SUNSHINE_CLIENT_WIDTH:-1920}x''${SUNSHINE_CLIENT_HEIGHT:-1080}@''${SUNSHINE_CLIENT_FPS:-60}\", position = \"auto-right\", scale = 1 })"
    hyprctl clients -j | $jq -r '.[] | select(.workspace.name == "2" and .fullscreen != 0) | .address' |
    while read -r a; do
      hyprctl dispatch "hl.dsp.focus({ window = \"address:$a\" })"
      hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen" })'
    done
    for _ in $(seq 25); do
      hyprctl dispatch 'hl.dsp.workspace.move({ workspace = "2", monitor = "SUNSHINE" })'
      hyprctl workspaces -j | $jq -e 'any(.[]; .name == "2" and .monitor == "SUNSHINE")' >/dev/null && break
      sleep 0.2
    done
    hyprctl dispatch 'hl.dsp.focus({ workspace = "2" })'
    sleep 0.5
    hyprctl clients -j | $jq -r '.[] | select((.class | startswith("steam_app_")) and .fullscreen == 0) | .address' |
    while read -r a; do
      hyprctl dispatch "hl.dsp.focus({ window = \"address:$a\" })"
      hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen" })'
    done
  '';
  # XWayland games sometimes map on the wrong workspace despite the ws-2 rule; pull them back.
  gameWatch = pkgs.writeShellScript "sunshine-game-watch" ''
    ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
    while IFS= read -r ev; do
      # Reloads (e.g. Noctalia's wallpaper→theme) reset SUNSHINE's mode and re-pin ws 2 to the Alienware.
      if [ "''${ev%%>>*}" = configreloaded ]; then
        sleep 0.5
        ${lendWs2}
        continue
      fi
      case "$ev" in openwindow\>\>*|movewindowv2\>\>*) ;; *) continue ;; esac
      hyprctl clients -j | ${pkgs.jq}/bin/jq -r '.[] | select((.class | startswith("steam_app_")) and .workspace.name != "2") | .address' |
      while read -r a; do
        hyprctl dispatch "hl.dsp.window.move({ workspace = \"2\", window = \"address:$a\", follow = true })"
      done
      # Games launched mid-stream open windowed under fullscreen Big Picture; bring them over it.
      case "$ev" in openwindow\>\>*) ;; *) continue ;; esac
      sleep 1
      hyprctl clients -j | ${pkgs.jq}/bin/jq -r '.[] | select((.class | startswith("steam_app_")) and .fullscreen == 0 and (.floating | not)) | .address' |
      while read -r a; do
        hyprctl dispatch "hl.dsp.focus({ window = \"address:$a\" })"
        hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen" })'
      done
    done
  '';
  streamDisplay = pkgs.writeShellScript "sunshine-stream-display" ''
    # Hyprland-only; elsewhere Sunshine falls back to streaming monitor 0.
    [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || exit 0

    case "$1" in
    start)
      # Clear a leftover from a stream whose undo never ran.
      hyprctl output destroy SUNSHINE >/dev/null 2>&1
      # Noctalia rewrites noctalia.lua on wallpaper changes; no auto-reload mid-stream.
      hyprctl eval 'hl.config({ misc = { disable_autoreload = true } })'
      ${puck "0"}
      hyprctl output create headless SUNSHINE
      # Output appears asynchronously; mode/workspace calls before then silently fail.
      for _ in $(seq 50); do
        hyprctl monitors -j | ${pkgs.jq}/bin/jq -e 'any(.[]; .name == "SUNSHINE")' >/dev/null && break
        sleep 0.1
      done
      # Hypr rules pin Steam + games to workspace 2; lend it to the stream.
      ${lendWs2}
      # XWayland games size borderless windows from the X11 primary output.
      ${pkgs.xrandr}/bin/xrandr --output SUNSHINE --primary
      [ -f "${watchPid}" ] && kill -- "-$(cat "${watchPid}")" 2>/dev/null
      setsid ${gameWatch} >/dev/null 2>&1 < /dev/null & echo $! > "${watchPid}"
      ;;
    stop)
      [ -f "${watchPid}" ] && kill -- "-$(cat "${watchPid}")" 2>/dev/null; rm -f "${watchPid}"
      hyprctl dispatch 'hl.dsp.workspace.move({ workspace = "2", monitor = "desc:${alienware}" })'
      hyprctl output destroy SUNSHINE
      aw=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.model == "Dell AW3423DW") | .name')
      [ -n "$aw" ] && ${pkgs.xrandr}/bin/xrandr --output "$aw" --primary
      # Re-enable and pick up any theme changes made during the stream.
      hyprctl eval 'hl.config({ misc = { disable_autoreload = false } })'
      ${puck "1"}
      hyprctl reload
      ;;
    esac
  '';
in
{
  # Let the stream script (user) disconnect/reconnect the puck via sysfs.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1304", RUN+="${pkgs.coreutils}/bin/chgrp users /sys%p/authorized", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/authorized"
  '';

  services.sunshine = {
    enable = true;
    # CUDA build → NVENC encoding (default build falls back to CPU x264).
    package = pkgs.sunshine.override { cudaSupport = true; };
    openFirewall = true;
    settings = {
      sunshine_name = "gavos";
      # Pin to wlr screencopy — otherwise Sunshine probes the portal backend
      # too, popping the screen-share picker on every login.
      capture = "wlr";
      # Tray "Quit" kills the service; relaunching from the menu then runs unconfigured.
      system_tray = "disabled";
      # Matched by output name (falls back to monitor 0 when absent).
      output_name = "SUNSHINE";
      global_prep_cmd = builtins.toJSON [
        {
          do = "${streamDisplay} start";
          undo = "${streamDisplay} stop";
        }
      ];
    };
    applications.apps = [
      {
        name = "Steam Big Picture";
        image-path = "steam.png";
        detached = [ "setsid steam steam://open/bigpicture" ];
        prep-cmd = [ { do = ""; undo = "setsid steam steam://close/bigpicture"; } ];
      }
      {
        name = "Desktop";
        image-path = "desktop.png";
      }
    ];
  };
}
