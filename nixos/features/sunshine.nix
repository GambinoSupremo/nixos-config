# Sunshine (Moonlight streaming host) with a per-stream headless virtual
# display sized to the client. Hyprland-only; other sessions stream the
# physical (letterboxed) desktop.
{ config, lib, pkgs, ... }:

let
  # Clients are 16:9 but the AW3423DW only has 21:9 modes, so each stream gets a
  # headless virtual display at the client's exact size, restored on disconnect.
  streamDisplay = pkgs.writeShellScript "sunshine-stream-display" ''
    # Hyprland-only; no-op elsewhere so other sessions still stream (letterboxed).
    [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || exit 0

    case "$1" in
    start)
      w=''${SUNSHINE_CLIENT_WIDTH:-1920}
      h=''${SUNSHINE_CLIENT_HEIGHT:-1080}
      fps=''${SUNSHINE_CLIENT_FPS:-60}
      hyprctl output create headless SUNSHINE
      hyprctl eval "hl.monitor({ output = \"SUNSHINE\", mode = \"''${w}x''${h}@''${fps}\", position = \"0x0\", scale = 1 })"
      # Disable physical outputs only after the virtual one exists — never zero monitors.
      hyprctl eval 'hl.monitor({ output = "DP-2", disabled = true })'
      hyprctl eval 'hl.monitor({ output = "DP-1", disabled = true })'
      ;;
    stop)
      # reload re-applies monitor.lua (HDR/VRR/positions) before the virtual
      # display disappears and workspaces migrate home.
      hyprctl reload
      sleep 1
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
      # Runs around every stream. Declaring `settings` makes the web UI's
      # general settings read-only (pairing + app list still work).
      global_prep_cmd = builtins.toJSON [
        {
          do = "${streamDisplay} start";
          undo = "${streamDisplay} stop";
        }
      ];
    };
  };
}
