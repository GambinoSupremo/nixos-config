# Game streaming to the Steam Machine (Sunshine + Moonlight). Each stream gets
# its own invisible screen sized for the TV; my monitors stay on.
# Steam Remote Play uses the same screen.
{
  config,
  lib,
  pkgs,
  host,
  ...
}:

let
  alienware = config.gav.monitors.main.desc;
  alienwareModel = config.gav.monitors.main.model;
  # Steam Controller puck: unplugged during a stream, or a controller paired
  # to it takes player 1 from the Moonlight one.
  puck = state: ''
    for d in /sys/bus/usb/devices/*; do
      [ "$(cat "$d/idVendor" 2>/dev/null):$(cat "$d/idProduct" 2>/dev/null)" = 28de:1304 ] && echo ${state} > "$d/authorized"
    done
  '';
  watchPid = "$XDG_RUNTIME_DIR/sunshine-game-watch.pid";

  # --- Hyprland ---
  # Moves workspace 2 (Steam + games) onto the stream screen. Fullscreen windows
  # can block the move, so it drops fullscreen, retries, then restores it.
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
    # Focus a running game (fullscreen) so Big Picture doesn't keep the controller on reconnect.
    hyprctl clients -j | $jq -r '.[] | select((.class | test("^steam_app_|[.]exe$")) and (.floating | not) and (.title | test("^Battle[.]net") | not)) | "\(.address) \(.fullscreen)"' |
    while read -r a fs; do
      hyprctl dispatch "hl.dsp.focus({ window = \"address:$a\" })"
      [ "$fs" = 0 ] && hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set" })'
    done
  '';
  # Runs during a stream: pulls games that open on the wrong workspace back
  # to 2, and focuses and fullscreens each new one.
  gameWatch = pkgs.writeShellScript "sunshine-game-watch" ''
    ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
    while IFS= read -r ev; do
      # Reloads (e.g. Noctalia's wallpaper→theme) reset SUNSHINE's mode and re-pin ws 2 to the Alienware.
      if [ "''${ev%%>>*}" = configreloaded ]; then
        sleep 0.5
        ${lendWs2}
        continue
      fi
      # Hyprland 0.57: the steam-games monitor rule pulls ws 2 back to the Alienware when a game maps.
      case "$ev" in
      moveworkspacev2\>\>2,*)
        [ "''${ev##*,}" = SUNSHINE ] && continue
        hyprctl dispatch 'hl.dsp.workspace.move({ workspace = 2, monitor = "SUNSHINE" })'
        sleep 0.2
        # A fullscreen game can block the move and strand ws 2.
        hyprctl workspaces -j | ${pkgs.jq}/bin/jq -e 'any(.[]; .name == "2" and .monitor == "SUNSHINE")' >/dev/null || ${lendWs2}
        continue ;;
      esac
      case "$ev" in openwindow\>\>*|movewindowv2\>\>*) ;; *) continue ;; esac
      # Battle.net's main window stays hidden (dotfiles hypr/rule.lua), even on a stream.
      hyprctl clients -j | ${pkgs.jq}/bin/jq -r '.[] | select((.class | test("^steam_app_|[.]exe$")) and .workspace.name != "2" and .title != "Battle.net") | .address' |
      while read -r a; do
        hyprctl dispatch "hl.dsp.window.move({ workspace = \"2\", window = \"address:$a\", follow = true })"
      done
      # Games open "silent" (unfocused) behind Big Picture, which then eats the controller.
      # Focus each new game window and make sure it's fullscreen.
      case "$ev" in openwindow\>\>*) ;; *) continue ;; esac
      IFS=, read -r a _ cls _ <<< "''${ev#openwindow>>}"
      case "$cls" in steam_app_*|*.exe) ;; *) continue ;; esac
      sleep 1
      # Battle.net shares WoW's class but isn't a game; its title arrives after it opens.
      hyprctl clients -j | ${pkgs.jq}/bin/jq -e --arg a "0x$a" '.[] | select(.address == $a and (.title | test("^Battle[.]net")))' >/dev/null && continue
      hyprctl dispatch "hl.dsp.focus({ window = \"address:0x$a\" })"
      hyprctl clients -j | ${pkgs.jq}/bin/jq -e --arg a "0x$a" '.[] | select(.address == $a and .fullscreen == 0 and (.floating | not))' >/dev/null &&
        hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set" })'
    done
  '';
  # Starts WoW on the stream. Waits for Battle.net to sign in first, otherwise
  # WoW asks for the password; if sign-in fails, WoW isn't started.
  wowLaunch = pkgs.writeShellScript "sunshine-wow-launch" ''
    # Reopening the stream onto a running game: gameWatch already put it on the stream.
    ${pkgs.procps}/bin/pgrep -x Wow.exe >/dev/null && exit 0
    (
      while :; do
        # The stream can sit on an empty workspace, hiding the sign-in window.
        hyprctl dispatch 'hl.dsp.focus({ workspace = "2" })'
        # Keep a real password prompt usable on the stream.
        a=$(hyprctl clients -j | ${pkgs.jq}/bin/jq -r 'first(.[] | select(.class == "steam_app_default" and .title == "Battle.net Login" and (.floating | not)) | .address) // empty')
        if [ -n "$a" ]; then
          hyprctl dispatch "hl.dsp.window.float({ action = \"enable\", window = \"address:$a\" })"
          hyprctl dispatch "hl.dsp.window.resize({ x = 600, y = 700, window = \"address:$a\" })"
          hyprctl dispatch "hl.dsp.window.center({ window = \"address:$a\" })"
        fi
        ${pkgs.coreutils}/bin/sleep 1
      done
    ) >/dev/null 2>&1 &
    keep_visible=$!
    ${pkgs.systemd}/bin/systemctl --user start battlenet-signin.service
    rc=$?
    kill "$keep_visible"
    if [ "$rc" -ne 0 ]; then
      ${pkgs.libnotify}/bin/notify-send "WoW Forever" "Battle.net didn't sign in. WoW wasn't started."
      exit 1
    fi
    # WoW can draw its menus and scene misaligned on the stream until its window changes size.
    (
      for _ in $(${pkgs.coreutils}/bin/seq 300); do
        a=$(hyprctl clients -j | ${pkgs.jq}/bin/jq -r 'first(.[] | select(.title == "World of Warcraft") | .address) // empty')
        [ -n "$a" ] && break
        ${pkgs.coreutils}/bin/sleep 1
      done
      [ -n "$a" ] || exit 0
      ${pkgs.coreutils}/bin/sleep 20
      hyprctl dispatch "hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = \"address:$a\" })"
      ${pkgs.coreutils}/bin/sleep 4
      hyprctl dispatch "hl.dsp.window.fullscreen_state({ internal = 2, client = 2, window = \"address:$a\" })"
    ) >/dev/null 2>&1 &
    exec ${pkgs.coreutils}/bin/env LUTRIS_SKIP_INIT=1 ${pkgs.lutris}/bin/lutris lutris:rungameid/6
  '';
  # Closes whatever game Steam is running, then goes back to Big Picture.
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
  # Sets the stream screen up when a stream starts and puts everything back after.
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
      # A fullscreen game can block the move, so drop fullscreen until the output is gone.
      full=$(hyprctl clients -j | ${pkgs.jq}/bin/jq -r '.[] | select(.workspace.id == 2 and .fullscreen != 0) | "\(.address) \(.fullscreen) \(.fullscreenClient)"')
      while read -r a _; do
        [ -n "$a" ] && hyprctl dispatch "hl.dsp.window.fullscreen_state({ internal = 0, client = 0, window = \"address:$a\" })"
      done <<< "$full"
      for _ in $(seq 25); do
        hyprctl dispatch 'hl.dsp.workspace.move({ workspace = "2", monitor = "desc:${alienware}" })'
        hyprctl workspaces -j | ${pkgs.jq}/bin/jq -e 'any(.[]; .id == 2 and .monitor == "SUNSHINE") | not' >/dev/null && break
        sleep 0.2
      done
      hyprctl output destroy SUNSHINE
      aw=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r '.[] | select(.model == "${alienwareModel}") | .name')
      [ -n "$aw" ] && ${pkgs.xrandr}/bin/xrandr --output "$aw" --primary
      # Re-enable and pick up any theme changes made during the stream.
      hyprctl eval 'hl.config({ misc = { disable_autoreload = false } })'
      hyprctl reload
      while read -r a i c; do
        [ -n "$a" ] && hyprctl dispatch "hl.dsp.window.fullscreen_state({ internal = $i, client = $c, window = \"address:$a\" })"
      done <<< "$full"
      ;;
    esac
  '';

  # --- Mango (only used when the Mango session is on) ---
  # Mango's workspaces belong to a monitor, so this moves the Steam windows instead.
  mmsg = "${pkgs.mango}/bin/mmsg";
  isSteam = ''.appid == "steam" or (.appid | startswith("steam_app_"))'';
  mangoLend = pkgs.writeShellScript "sunshine-mango-lend" ''
    jq=${pkgs.jq}/bin/jq
    ${pkgs.wlr-randr}/bin/wlr-randr --output SUNSHINE \
      --custom-mode "''${SUNSHINE_CLIENT_WIDTH:-1920}x''${SUNSHINE_CLIENT_HEIGHT:-1080}@''${SUNSHINE_CLIENT_FPS:-60}Hz"
    # Runtime rules (later wins over rule.conf) so new Steam windows open on the stream.
    ${mmsg} dispatch 'setoption,window_rule,tags:2,monitor:SUNSHINE,app_id:^steam$'
    ${mmsg} dispatch 'setoption,window_rule,tags:2,monitor:SUNSHINE,app_id:^steam_app_'
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
  # Same job as gameWatch.
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
          ${mmsg} dispatch 'tagmon,model:${alienwareModel},1' "client,$id" >/dev/null
        done
        sleep 0.2
      done
      [ -z "$(onStream)" ] && ${mmsg} dispatch destroy_all_virtual_output
      # Drops the stream's runtime window rules.
      ${mmsg} dispatch reload_config
      ;;
    esac
  '';

  # --- Start and stop ---
  # What Sunshine runs when a stream starts and ends; picks the right desktop.
  streamDisplay = pkgs.writeShellScript "sunshine-stream-display" ''
    [ "$1" = start ] && { ${puck "0"} }
    # Elsewhere (niri) Sunshine falls back to streaming monitor 0.
    case "$XDG_CURRENT_DESKTOP" in
    Hyprland) ${hyprStream} "$1" ;;
    ${lib.optionalString config.gav.sessions.mango ''mango) ${mangoStream} "$1" ;;''}
    esac
    [ "$1" = stop ] && { ${puck "1"} }
    exit 0
  '';
  # Remote Play has no start/stop hook, so this watches Steam's log and does
  # the same setup at the Steam Machine's 1440p 120 Hz.
  remotePlayWatch = pkgs.writeShellScript "remoteplay-watch" ''
    log="$HOME/.local/share/Steam/logs/streaming_log.txt"
    flag="$XDG_RUNTIME_DIR/remoteplay-active"
    rm -f "$flag"
    ${pkgs.coreutils}/bin/tail -F -n0 "$log" 2>/dev/null | while IFS= read -r line; do
      case "$line" in
      *"Streaming started to "*)
        # Skip if a Moonlight stream already owns SUNSHINE.
        ${pkgs.wlr-randr}/bin/wlr-randr --json | ${pkgs.jq}/bin/jq -e 'any(.[]; .name == "SUNSHINE")' >/dev/null && continue
        touch "$flag"
        SUNSHINE_CLIENT_WIDTH=2560 SUNSHINE_CLIENT_HEIGHT=1440 SUNSHINE_CLIENT_FPS=120 ${streamDisplay} start
        ;;
      *"PipeWire: Unloading null sink"*)
        [ -f "$flag" ] && { rm -f "$flag"; ${streamDisplay} stop; }
        ;;
      esac
    done
  '';
in
lib.mkIf config.gav.features.streaming.enable {
  # --- Controller puck ---
  # Lets the stream script switch the puck off and on without sudo.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1304", RUN+="${pkgs.coreutils}/bin/chgrp users /sys%p/authorized", RUN+="${pkgs.coreutils}/bin/chmod g+w /sys%p/authorized"
  '';

  # --- Remote Play watcher ---
  systemd.user.services.remoteplay-watch = {
    description = "Virtual display for Steam Remote Play sessions";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    # The stream scripts need hyprctl and setsid.
    path = [
      config.programs.hyprland.package
      pkgs.util-linux
    ];
    serviceConfig = {
      ExecStart = remotePlayWatch;
      Restart = "on-failure";
    };
  };

  # --- Sunshine ---
  services.sunshine = {
    enable = true;
    openFirewall = true;
    settings = {
      sunshine_name = host.hostName;
      # Without this the screen-share picker pops up on every login.
      capture = "wlr";
      # The tray's Quit kills the service and it comes back without these settings.
      system_tray = "disabled";
      # The stream screen; falls back to the first monitor if it's missing.
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
        name = "WoW Forever";
        detached = [ "${pkgs.util-linux}/bin/setsid ${wowLaunch}" ];
      }
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
