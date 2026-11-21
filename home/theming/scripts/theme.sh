# shellcheck shell=bash
# Switch themes (palette + wallpapers) and run onThemeChange hooks.
# Inputs from runtimeEnv: THEMES_LIST, THEME_THUMBS, THEME_HOOKS_FILE.

themes="$THEMES_LIST"
thumbs="$THEME_THUMBS"
sdir="${XDG_STATE_HOME:-$HOME/.local/state}"
state="$sdir/theme-current"
# Themes added from GitHub links (theme-install).
[ -s "$sdir/theme-added" ] && themes+=$'\n'$(cat "$sdir/theme-added")
added_thumbs="${XDG_CACHE_HOME:-$HOME/.cache}/theme-thumbs"

current() { cat "$state" 2>/dev/null || echo Wallpaper; }
field() { grep -m1 "^$1|" <<<"$themes" | cut -d'|' -f"$2"; }
names() { awk -F'|' -v m="$1" '$2 == m { print $1 }' <<<"$themes"; }
mode_of() {
  local m
  m=$(field "$1" 2)
  echo "${m:-dark}"
}
other() { [ "$1" = dark ] && echo light || echo dark; }

apply() {
  local line name mode source palette dir
  line=$(grep -m1 "^$1|" <<<"$themes") || {
    echo "unknown theme: $1" >&2
    exit 1
  }
  IFS='|' read -r name mode source palette dir <<<"$line"
  dir="$HOME/Pictures/$dir"
  noctalia msg theme-mode-set "$mode" >/dev/null
  noctalia msg color-scheme-set "$source" "$palette" >/dev/null
  if find -L "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit 2>/dev/null | grep -q .; then
    noctalia msg config-set wallpaper.directory "'$dir'" >/dev/null
    noctalia msg wallpaper-random >/dev/null
  else
    notify-send -a Theme "$name" "No wallpapers in $dir yet; kept the current ones."
  fi
  echo "$name" >"$state"
  echo "$name" >"$sdir/theme-last-$mode"
  [ -n "${THEME_NOTIFY:-}" ] && notify-send -a Theme -t 2000 "Theme" "$name"
  export THEME_NAME="$name" THEME_MODE="$mode" THEME_SOURCE="$source" THEME_PALETTE="$palette" THEME_DIR="$dir"
  # shellcheck source=/dev/null
  source "$THEME_HOOKS_FILE"
}

# Next or previous theme in the current mode (bar scroll, Super+Ctrl+T).
step() {
  local list cur i n
  cur=$(current)
  mapfile -t list < <(names "$(mode_of "$cur")")
  n=${#list[@]}
  for i in "${!list[@]}"; do [ "${list[$i]}" = "$cur" ] && break; done
  THEME_NOTIFY=1 apply "${list[$(((i + $1 + n) % n))]}"
}

# Light <-> dark: back to the last theme used in the other mode.
toggle() {
  local m t
  m=$(other "$(mode_of "$(current)")")
  t=$(cat "$sdir/theme-last-$m" 2>/dev/null || names "$m" | head -1)
  THEME_NOTIFY=1 apply "$t"
}

# Menu rows: name, subtitle, thumbnail. Current mode first.
rows() {
  local cur m name mode dir sub thumb t
  cur=$(current)
  m=$(mode_of "$cur")
  {
    awk -F'|' -v m="$m" '$2 == m' <<<"$themes"
    awk -F'|' -v m="$m" '$2 != m' <<<"$themes"
  } |
    while IFS='|' read -r name mode _ _ dir; do
      sub=${mode^}
      [ "$name" = "$cur" ] && sub="$sub · current"
      thumb=""
      for t in "$added_thumbs/${dir##*/}.png" "$thumbs/${dir##*/}.png"; do
        [ -e "$t" ] && thumb=$t && break
      done
      printf '%s\t%s\t%s\n' "$name" "$sub" "$thumb"
    done
}

case "${1:-}" in
  list)
    cut -d'|' -f1,2 <<<"$themes" | tr '|' '\t'
    exit
    ;;
  rows)
    rows
    exit
    ;;
  current)
    current
    exit
    ;;
  install)
    shift
    exec theme-install "$@"
    ;;
  "") exec sysmenu style.theme ;;
esac

# One switch at a time, so fast scrolling doesn't pile up.
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/theme.lock"
flock -n 9 || exit 0

case "${1:-}" in
  next) step 1 ;;
  prev) step -1 ;;
  toggle) toggle ;;
  *) apply "$*" ;;
esac
