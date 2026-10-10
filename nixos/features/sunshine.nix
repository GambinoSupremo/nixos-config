# Sunshine (Moonlight streaming host). Each stream gets a headless virtual
# display at the client's resolution/refresh; physical monitors stay on.
{ pkgs, host, ... }:

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
  # Kill whatever Steam is running (every process under its reaper), then back to Big Picture.
  closeGame = pkgs.writeShellScript "sunshine-close-game" ''
    tree() { echo "$1"; for c in $(${pkgs.procps}/bin/ps -o pid= --ppid "$1"); do tree "$c"; done; }
    pids=$(${pkgs.procps}/bin/ps -eo pid=,args= | ${pkgs.gawk}/bin/awk '$2 ~ /\/reaper$/ && $3 == "SteamLaunch" { print $1 }' |
      while read -r r; do tree "$r"; done)
    if [ -n "$pids" ]; then
      kill -TERM $pids 2>/dev/null
      sleep 5
      kill -KILL $pids 2>/dev/null
    fi
    steam steam://open/bigpicture
  '';
  hyprStream = pkgs.writeShellScript "sunshine-hypr-stream" ''
    case "$1" in
    start)
      # Clear a leftover from a stream whose undo never ran.
      hyprctl output destroy SUNSHINE >/dev/null 2>&1
      # Noctalia rewrites noctalia.lua on wallpaper changes; no auto-reload mid-stream.
      hyprctl eval 'hl.config({ misc = { disable_autoreload = true } })'
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
      hyprctl reload
      ;;
    esac
  '';

  # ── Mango ──────────────────────────────────────────────────────────────────
  # Mango tags are per monitor, so move the Steam windows themselves. monitor.conf's
  # SUNSHINE rule makes it the X11 primary; its mode survives config reloads.
  mmsg = "${pkgs.mango}/bin/mmsg";
  isSteam = ''.appid == "steam" or (.appid | startswith("steam_app_"))'';
  mangoLend = pkgs.writeShellScript "sunshine-mango-lend" ''
    jq=${pkgs.jq}/bin/jq
    ${pkgs.wlr-randr}/bin/wlr-randr --output SUNSHINE \
      --custom-mode "''${SUNSHINE_CLIENT_WIDTH:-1920}x''${SUNSHINE_CLIENT_HEIGHT:-1080}@''${SUNSHINE_CLIENT_FPS:-60}Hz"
    # Runtime rules (later wins over rule.conf) so new Steam windows open on the stream.
    ${mmsg} dispatch 'setoption,windowrule,tags:2,monitor:SUNSHINE,appid:^steam$'
    ${mmsg} dispatch 'setoption,windowrule,tags:2,monitor:SUNSHINE,appid:^steam_app_'
    ${mmsg} get all-clients | $jq -r '.clients[] | select((${isSteam}) and .monitor != "SUNSHINE") | .id' |
    while read -r id; do
      ${mmsg} dispatch tagmon,SUNSHINE,1 "client,$id"
    done
    ${mmsg} dispatch focusmon,SUNSHINE
    ${mmsg} dispatch view,2,0
    ${mmsg} get all-clients | $jq -r '.clients[] | select((.appid | startswith("steam_app_")) and (.is_fullscreen or .is_floating | not)) | .id' |
    while read -r id; do
      ${mmsg} dispatch togglefullscreen "client,$id"
    done
  '';
  # Pull stray games onto the stream (Noctalia's theme apply reloads Mango, dropping the
  # runtime rules) and fullscreen each new one, like gameWatch.
  mangoGameWatch = pkgs.writeShellScript "sunshine-mango-game-watch" ''
    jq=${pkgs.jq}/bin/jq
    seen=" "
    ${mmsg} watch all-clients | while IFS= read -r ev; do
      while read -r id mon; do
        [ -n "$id" ] || continue
        [ "$mon" = SUNSHINE ] || ${mmsg} dispatch tagmon,SUNSHINE,1 "client,$id" >/dev/null
        case "$seen" in *" $id "*) continue ;; esac
        seen="$seen$id "
        sleep 1
        ${mmsg} get client "$id" | $jq -e '.is_fullscreen or .is_floating' >/dev/null ||
          ${mmsg} dispatch togglefullscreen "client,$id" >/dev/null
      done <<< "$(echo "$ev" | $jq -r '.clients[]? | select(.appid | startswith("steam_app_")) | "\(.id) \(.monitor)"')"
    done
  '';
  mangoStream = pkgs.writeShellScript "sunshine-mango-stream" ''
    jq=${pkgs.jq}/bin/jq
    onStream() { ${mmsg} get all-clients | $jq -r '.clients[] | select(.monitor == "SUNSHINE") | .id'; }
    case "$1" in
    start)
      # Reuse a leftover from a stream whose undo never ran; windows on it stay put.
      if ! ${mmsg} get all-monitors | $jq -e 'any(.monitors[]; .name == "SUNSHINE")' >/dev/null; then
        ${mmsg} dispatch create_virtual_output,SUNSHINE
        for _ in $(seq 50); do
          ${mmsg} get all-monitors | $jq -e 'any(.monitors[]; .name == "SUNSHINE")' >/dev/null && break
          sleep 0.1
        done
      fi
      ${mangoLend}
      [ -f "${watchPid}" ] && kill -- "-$(cat "${watchPid}")" 2>/dev/null
      setsid ${mangoGameWatch} >/dev/null 2>&1 < /dev/null & echo $! > "${watchPid}"
      ;;
    stop)
      [ -f "${watchPid}" ] && kill -- "-$(cat "${watchPid}")" 2>/dev/null; rm -f "${watchPid}"
      # Windows left on a destroyed output are stranded until it comes back; move them all first.
      for _ in $(seq 10); do
        ids=$(onStream)
        [ -n "$ids" ] || break
        for id in $ids; do
          ${mmsg} dispatch 'tagmon,model:Dell AW3423DW,1' "client,$id" >/dev/null
        done
        sleep 0.2
      done
      [ -z "$(onStream)" ] && ${mmsg} dispatch destroy_all_virtual_output
      # Drops the stream's runtime window rules.
      ${mmsg} dispatch reload_config
      ;;
    esac
  '';

  streamDisplay = pkgs.writeShellScript "sunshine-stream-display" ''
    [ "$1" = start ] && { ${puck "0"} }
    # Elsewhere (niri) Sunshine falls back to streaming monitor 0.
    case "$XDG_CURRENT_DESKTOP" in
    Hyprland) ${hyprStream} "$1" ;;
    mango) ${mangoStream} "$1" ;;
    esac
    [ "$1" = stop ] && { ${puck "1"} }
    exit 0
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
      sunshine_name = host.hostName;
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
        prep-cmd = [
          {
            do = "";
            undo = "setsid steam steam://close/bigpicture";
          }
        ];
      }
      {
        name = "Close game";
        image-path = "steam.png";
        detached = [ "setsid ${closeGame}" ];
        prep-cmd = [
          {
            do = "";
            undo = "setsid steam steam://close/bigpicture";
          }
        ];
      }
      {
        name = "Desktop";
        image-path = "desktop.png";
      }
    ];
  };
}
