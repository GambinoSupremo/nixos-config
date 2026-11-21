# shellcheck shell=bash
# Toggle Hyprland window gaps or transparency/blur live.

case "${1:-}" in
  gaps)
    cur=$(hyprctl getoption general:gaps_in -j | jq -r '.css // "5"' | awk '{print $1}')
    if [ "$cur" = "0" ]; then
      hyprctl eval 'hl.config({ general = { gaps_in = 5, gaps_out = 10 } })' >/dev/null
      notify-send -a Desktop -t 2000 "Window gaps" "Normal"
    else
      hyprctl eval 'hl.config({ general = { gaps_in = 0, gaps_out = 0 } })' >/dev/null
      notify-send -a Desktop -t 2000 "Window gaps" "Off"
    fi
    ;;
  opacity)
    blur=$(hyprctl getoption decoration:blur:enabled -j | jq -r '.int // 1')
    if [ "$blur" = "0" ]; then
      hyprctl eval 'hl.config({ decoration = { inactive_opacity = 0.98, blur = { enabled = true } } })' >/dev/null
      notify-send -a Desktop -t 2000 "Window transparency" "On"
    else
      hyprctl eval 'hl.config({ decoration = { inactive_opacity = 1.0, blur = { enabled = false } } })' >/dev/null
      notify-send -a Desktop -t 2000 "Window transparency" "Solid"
    fi
    ;;
  *)
    echo "usage: hypr-toggle gaps|opacity" >&2
    exit 1
    ;;
esac
