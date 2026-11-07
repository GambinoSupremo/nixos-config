# theme: named looks (Noctalia palette + matching wallpaper folder), like Omarchy's themes.
# Wallpapers live in ~/Pictures/themes/<slug>; "Wallpaper" = colors from the wallpaper.
{ pkgs, ... }:

let
  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [ pkgs.libnotify ];
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
      themes=$(sed 's/^ *//' <<<"$themes")
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/theme-current"

      current() { cat "$state" 2>/dev/null || echo Wallpaper; }

      apply() {
        local line name source palette dir
        line=$(grep -m1 "^$1|" <<<"$themes") || { echo "unknown theme: $1" >&2; exit 1; }
        IFS='|' read -r name source palette dir <<<"$line"
        dir="$HOME/Pictures/$dir"
        noctalia msg color-scheme-set "$source" "$palette" >/dev/null
        if find "$dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit 2>/dev/null | grep -q .; then
          noctalia msg config-set wallpaper.directory "'$dir'" >/dev/null
          noctalia msg wallpaper-random >/dev/null
        else
          notify-send -a Theme "$name" "No wallpapers in $dir yet; kept the current ones."
        fi
        echo "$name" >"$state"
      }

      case "''${1:-}" in
        list) cut -d'|' -f1 <<<"$themes" ;;
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
