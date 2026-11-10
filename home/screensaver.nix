# screensaver: terminal text effects, full screen on every monitor (Hyprland), gone on any input.
# Noctalia starts it after 30 idle minutes and blanks the screens after 60, never while gaming.
{ pkgs, ... }:

let
  logo = pkgs.runCommand "screensaver-logo" { } ''
    ${pkgs.figlet}/bin/figlet -f slant gavos >$out
  '';

  # Runs inside each fullscreen terminal.
  loop = pkgs.writeShellScript "screensaver-loop" ''
    printf '\e[?25l'
    while :; do
      printf '\e[2J\e[H'
      ${pkgs.terminaltexteffects}/bin/tte -i ${logo} --frame-rate 120 \
        --canvas-width 0 --canvas-height 0 --anchor-canvas c --anchor-text c \
        --random-effect --no-eol --no-restore-cursor
      sleep 3
    done
  '';

  screensaver = pkgs.writeShellApplication {
    name = "screensaver";
    runtimeInputs = [
      pkgs.jq
      pkgs.procps
      pkgs.swayidle
    ];
    text = ''
      hypr() { [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && hyprctl version >/dev/null 2>&1; }

      # A Steam game, or any fullscreen window that isn't the screensaver itself.
      gaming() {
        pgrep -f 'SteamLaunc[h] AppId=' >/dev/null && return 0
        hypr && hyprctl clients -j | jq -e 'any(.[]; .fullscreen >= 2 and .class != "screensaver")' >/dev/null
      }

      start() {
        hypr || exit 0
        pgrep -f 'ghostty .*--class=screensaver' >/dev/null && exit 0
        hyprctl monitors -j | jq -r '.[] | select(.disabled | not) | .name' | while read -r m; do
          hyprctl dispatch "hl.dsp.exec_cmd(\"ghostty --gtk-single-instance=false --class=screensaver --background=000000 --background-opacity=1 --font-size=28 --confirm-close-surface=false -e ${loop}\", { monitor = \"$m\", fullscreen = true })" >/dev/null
        done
        # Any key or mouse movement ends it, whoever started it.
        setsid swayidle timeout 2 true resume "$0 stop" >/dev/null 2>&1 &
      }

      stop() {
        pkill -f 'ghostty .*--class=screensaver' || true
        pkill -f 'swayidle timeout 2 true resume .*screensaver stop' || true
      }

      case "''${1:-start}" in
        start) start ;;
        stop) stop ;;
        idle) gaming || start ;;
        screen-off) gaming || noctalia msg dpms-off ;;
        *) echo "usage: screensaver [start|stop|idle|screen-off]" >&2; exit 1 ;;
      esac
    '';
  };
in
{
  home.packages = [ screensaver ];

  # Noctalia reads every .toml here on top of config.toml.
  xdg.configFile."noctalia/idle.toml".text = ''
    [idle.behavior.screensaver]
    timeout = 1800
    action = "command"
    command = "screensaver idle"
    resume_command = "screensaver stop"

    [idle.behavior.screen-off]
    timeout = 3600
    action = "command"
    command = "screensaver screen-off"
    resume_command = "noctalia msg dpms-on"
  '';
}
