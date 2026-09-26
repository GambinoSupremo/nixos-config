# Sunshine (Moonlight streaming host). Each stream gets a headless virtual
# display at the client's resolution/refresh; physical monitors stay on.
{ config, lib, pkgs, ... }:

let
  alienware = "Dell Inc. Dell AW3423DW #tBszGDAYBQUH";
  streamDisplay = pkgs.writeShellScript "sunshine-stream-display" ''
    # Hyprland-only; elsewhere Sunshine falls back to streaming monitor 0.
    [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || exit 0

    case "$1" in
    start)
      # Clear a leftover from a stream whose undo never ran.
      hyprctl output destroy SUNSHINE >/dev/null 2>&1
      hyprctl output create headless SUNSHINE
      hyprctl eval "hl.monitor({ output = \"SUNSHINE\", mode = \"''${SUNSHINE_CLIENT_WIDTH:-1920}x''${SUNSHINE_CLIENT_HEIGHT:-1080}@''${SUNSHINE_CLIENT_FPS:-60}\", position = \"auto-right\", scale = 1 })"
      # Hypr rules pin Steam + games to workspace 2; lend it to the stream.
      hyprctl dispatch 'hl.dsp.workspace.move({ workspace = "2", monitor = "SUNSHINE" })'
      hyprctl dispatch 'hl.dsp.focus({ workspace = "2" })'
      ;;
    stop)
      hyprctl dispatch 'hl.dsp.workspace.move({ workspace = "2", monitor = "desc:${alienware}" })'
      hyprctl output destroy SUNSHINE
      ;;
    esac
  '';
in
{
  # High-priority GPU context so capture isn't starved by the game; no sys_admin (wlr, not KMS).
  security.wrappers.sunshine.capabilities = lib.mkForce "cap_sys_nice+ep";

  services.sunshine = {
    enable = true;
    # CUDA build → NVENC encoding (default build falls back to CPU x264).
    package = pkgs.sunshine.override { cudaSupport = true; };
    openFirewall = true;
    # Enables the capability wrapper; caps overridden above.
    capSysAdmin = true;
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
