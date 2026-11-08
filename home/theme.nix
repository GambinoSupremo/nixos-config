# theme: named looks (Noctalia palette + matching wallpaper folder), like Omarchy's themes.
# Wallpapers live in ~/Pictures/themes/<slug>; "Wallpaper" = colors from the wallpaper.
{ pkgs, ... }:

let
  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.util-linux # flock
    ];
    text = ''
      # name|source|palette|wallpaper folder (relative to ~/Pictures)
      themes='Wallpaper|wallpaper|m3-content|backgrounds
      Gruvbox|builtin|Gruvbox|themes/gruvbox
      Everforest|community|Everforest|themes/everforest
      Nord|builtin|Nord|themes/nord
      Catppuccin|builtin|Catppuccin|themes/catppuccin
      Tokyo Night|builtin|Tokyo-Night|themes/tokyo-night
      Kanagawa|builtin|Kanagawa|themes/kanagawa
      Rosé Pine|builtin|Rosé Pine|themes/rose-pine
      Dracula|builtin|Dracula|themes/dracula
      Ayu|builtin|Ayu|themes/ayu
      Eldritch|builtin|Eldritch|themes/eldritch
      Solarized|community|Solarized|themes/solarized'
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/theme-current"

      current() { cat "$state" 2>/dev/null || echo Wallpaper; }

      apply() {
        local line name source palette dir
        line=$(grep -m1 "^$1|" <<<"$themes") || { echo "unknown theme: $1" >&2; exit 1; }
        IFS='|' read -r name source palette dir <<<"$line"
        dir="$HOME/Pictures/$dir"
        noctalia msg color-scheme-set "$source" "$palette" >/dev/null
        if find -L "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit 2>/dev/null | grep -q .; then
          noctalia msg config-set wallpaper.directory "'$dir'" >/dev/null
          noctalia msg wallpaper-random >/dev/null
        else
          notify-send -a Theme "$name" "No wallpapers in $dir yet; kept the current ones."
        fi
        echo "$name" >"$state"
        [ -n "''${THEME_NOTIFY:-}" ] && notify-send -a Theme -t 2000 "Theme" "$name"
        # Login screen follows too, once the new wallpaper has landed.
        (sleep 3; noctalia msg greeter-sync >/dev/null 2>&1) 9>&- &
      }

      # Step through the list (wraps); used by the bar button scroll and Super+Ctrl+T.
      step() {
        local names cur i n
        mapfile -t names < <(cut -d'|' -f1 <<<"$themes")
        cur=$(current); n=''${#names[@]}
        for i in "''${!names[@]}"; do [ "''${names[$i]}" = "$cur" ] && break; done
        THEME_NOTIFY=1 apply "''${names[$(( (i + $1 + n) % n ))]}"
      }

      # One switch at a time, so fast scrolling doesn't pile up.
      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/theme.lock"
      flock -n 9 || exit 0

      case "''${1:-}" in
        list) cut -d'|' -f1 <<<"$themes" ;;
        next) step 1 ;;
        prev) step -1 ;;
        current) current ;;
        "")
          cur=$(current)
          pick=$(cut -d'|' -f1 <<<"$themes" | sed "s/^$cur\$/$cur  ·  current/" \
            | noctalia dmenu -p "Theme" || true)
          [ -n "$pick" ] && apply "''${pick%  ·  current}"
          ;;
        *) apply "$*" ;;
      esac
    '';
  };
in
{
  home.packages = [ theme ];
}
