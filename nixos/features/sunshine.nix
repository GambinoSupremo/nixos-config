# Sunshine (Moonlight streaming host). Each stream gets a headless virtual
# display at the client's resolution/refresh; physical monitors stay on.
{ config, lib, pkgs, ... }:

let
  alienware = "Dell Inc. Dell AW3423DW #tBszGDAYBQUH";
  watchPid = "$XDG_RUNTIME_DIR/sunshine-game-watch.pid";
  # XWayland games sometimes map on the wrong workspace despite the ws-2 rule; pull them back.
  gameWatch = pkgs.writeShellScript "sunshine-game-watch" ''
    ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
    while IFS= read -r ev; do
      case "$ev" in openwindow\>\>*|movewindowv2\>\>*) ;; *) continue ;; esac
      hyprctl clients -j | ${pkgs.jq}/bin/jq -r '.[] | select((.class | startswith("steam_app_")) and .workspace.name != "2") | .address' |
      while read -r a; do
        hyprctl dispatch "hl.dsp.window.move({ workspace = \"2\", window = \"address:$a\", follow = true })"
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
      hyprctl output create headless SUNSHINE
      # Output appears asynchronously; mode/workspace calls before then silently fail.
      for _ in $(seq 50); do
        hyprctl monitors -j | ${pkgs.jq}/bin/jq -e 'any(.[]; .name == "SUNSHINE")' >/dev/null && break
        sleep 0.1
      done
      hyprctl eval "hl.monitor({ output = \"SUNSHINE\", mode = \"''${SUNSHINE_CLIENT_WIDTH:-1920}x''${SUNSHINE_CLIENT_HEIGHT:-1080}@''${SUNSHINE_CLIENT_FPS:-60}\", position = \"auto-right\", scale = 1 })"
      # Hypr rules pin Steam + games to workspace 2; lend it to the stream.
      hyprctl dispatch 'hl.dsp.workspace.move({ workspace = "2", monitor = "SUNSHINE" })'
      hyprctl dispatch 'hl.dsp.focus({ workspace = "2" })'
      [ -f "${watchPid}" ] && kill -- "-$(cat "${watchPid}")" 2>/dev/null
      setsid ${gameWatch} >/dev/null 2>&1 < /dev/null & echo $! > "${watchPid}"
      ;;
    stop)
      [ -f "${watchPid}" ] && kill -- "-$(cat "${watchPid}")" 2>/dev/null; rm -f "${watchPid}"
      hyprctl dispatch 'hl.dsp.workspace.move({ workspace = "2", monitor = "desc:${alienware}" })'
      hyprctl output destroy SUNSHINE
      ;;
    esac
  '';
in
{
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
