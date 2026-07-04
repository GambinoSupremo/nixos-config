{ config, lib, pkgs, ... }:

let
  # Moonlight clients (Steam Machine / TV) are 16:9, but the AW3423DW only
  # exposes 21:9 modes — streaming the physical desktop always letterboxes.
  # So each stream gets a headless virtual display at exactly the client's
  # resolution: create it, disable the physical outputs (all workspaces and
  # windows migrate onto it), stream, then restore on disconnect. Sunshine
  # exports SUNSHINE_CLIENT_WIDTH/HEIGHT/FPS to prep commands.
  streamDisplay = pkgs.writeShellScript "sunshine-stream-display" ''
    # Hyprland-only; no-op elsewhere so a stream from another session still
    # starts (letterboxed) instead of erroring out.
    [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ] || exit 0

    case "$1" in
    start)
      w=''${SUNSHINE_CLIENT_WIDTH:-1920}
      h=''${SUNSHINE_CLIENT_HEIGHT:-1080}
      fps=''${SUNSHINE_CLIENT_FPS:-60}
      hyprctl output create headless SUNSHINE
      hyprctl eval "hl.monitor({ output = \"SUNSHINE\", mode = \"''${w}x''${h}@''${fps}\", position = \"0x0\", scale = 1 })"
      # Disable physical outputs only after the virtual one exists so there
      # is never a zero-monitor moment.
      hyprctl eval 'hl.monitor({ output = "DP-2", disabled = true })'
      hyprctl eval 'hl.monitor({ output = "DP-1", disabled = true })'
      ;;
    stop)
      # reload re-applies monitor.lua, bringing the physical outputs back
      # with their full config (HDR, VRR, positions) before the virtual
      # display disappears and the workspaces migrate home.
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
    # CUDA build so encoding uses NVENC on the RTX card; the default build
    # would fall back to CPU x264.
    package = pkgs.sunshine.override { cudaSupport = true; };
    # Ports 47984/47989/48010 TCP + 47998-48000/48002/48010 UDP.
    openFirewall = true;
    settings = {
      sunshine_name = "gavos";
      # Pin the capture backend to wlr screencopy (what Sunshine picks here
      # anyway). Without this it also probes the xdg-desktop-portal backend
      # at startup, which pops the compositor's screen-share picker dialog
      # on every login.
      capture = "wlr";
      # Runs around every stream regardless of which app Moonlight launches.
      # NOTE: because `settings` is declared here, general settings in the
      # web UI (https://localhost:47990) are read-only; pairing and the app
      # list still work from there.
      global_prep_cmd = builtins.toJSON [
        {
          do = "${streamDisplay} start";
          undo = "${streamDisplay} stop";
        }
      ];
    };
  };
}
