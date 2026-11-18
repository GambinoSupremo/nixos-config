# The `theme` command: each theme is a color palette plus a wallpaper folder
# in ~/Pictures/themes. `theme toggle` flips between dark and light; `theme`
# alone opens the list in the System menu with wallpaper thumbnails.
{ pkgs, inputs, ... }:

let
  # First wallpaper of each theme folder, cropped to a rounded square.
  thumbs = pkgs.runCommand "theme-thumbs" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    mkdir -p $out
    for dir in ${inputs.wallpapers}/themes/*/; do
      img=$(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) | sort | head -1)
      [ -n "$img" ] || continue
      magick "$img" -resize 128x128^ -gravity center -extent 128x128 \
        \( -size 128x128 xc:none -fill white -draw 'roundrectangle 0,0 127,127 26,26' \) \
        -compose DstIn -composite "$out/$(basename "$dir").png"
    done
  '';

  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.util-linux # flock
    ];
    text = ''
      # name|mode|source|palette|wallpaper folder (relative to ~/Pictures)
      themes='Wallpaper|dark|wallpaper|m3-content|themes
      Gruvbox|dark|builtin|Gruvbox|themes/gruvbox
      Everforest|dark|community|Everforest|themes/everforest
      Nord|dark|builtin|Nord|themes/nord
      Catppuccin|dark|builtin|Catppuccin|themes/catppuccin
      Tokyo Night|dark|builtin|Tokyo-Night|themes/tokyo-night
      Kanagawa|dark|builtin|Kanagawa|themes/kanagawa
      Rosé Pine|dark|builtin|Rosé Pine|themes/rose-pine
      Dracula|dark|builtin|Dracula|themes/dracula
      Ayu|dark|builtin|Ayu|themes/ayu
      Eldritch|dark|builtin|Eldritch|themes/eldritch
      Solarized|dark|community|Solarized|themes/solarized
      Jade Horse|dark|custom|Jade-Horse|themes/jade-horse
      Retro-82|dark|custom|Retro-82|themes/retro-82
      Solitude|dark|custom|Solitude|themes/solitude
      Hackerman|dark|custom|Hackerman|themes/hackerman
      Last Horizon|dark|custom|Last-Horizon|themes/last-horizon
      Lumon|dark|custom|Lumon|themes/lumon
      Matte Black|dark|custom|Matte-Black|themes/matte-black
      Miasma|dark|custom|Miasma|themes/miasma
      Ristretto|dark|custom|Ristretto|themes/ristretto
      Vantablack|dark|custom|Vantablack|themes/vantablack
      Catppuccin Latte|light|custom|Catppuccin-Latte|themes/catppuccin-latte
      Lupine|light|custom|Lupine|themes/lupine
      Flexoki Light|light|custom|Flexoki-Light|themes/flexoki-light
      White|light|custom|White|themes/white'
      thumbs=${thumbs}
      sdir="''${XDG_STATE_HOME:-$HOME/.local/state}"
      state="$sdir/theme-current"

      current() { cat "$state" 2>/dev/null || echo Wallpaper; }
      field() { grep -m1 "^$1|" <<<"$themes" | cut -d'|' -f"$2"; }
      names() { awk -F'|' -v m="$1" '$2 == m { print $1 }' <<<"$themes"; }
      mode_of() { local m; m=$(field "$1" 2); echo "''${m:-dark}"; }
      other() { [ "$1" = dark ] && echo light || echo dark; }

      apply() {
        local line name mode source palette dir
        line=$(grep -m1 "^$1|" <<<"$themes") || { echo "unknown theme: $1" >&2; exit 1; }
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
        [ -n "''${THEME_NOTIFY:-}" ] && notify-send -a Theme -t 2000 "Theme" "$name"
        # Login screen follows too, once the new wallpaper has landed.
        (sleep 3; noctalia msg greeter-sync >/dev/null 2>&1) 9>&- &
      }

      # Next or previous theme in the current mode (bar scroll, Super+Ctrl+T).
      step() {
        local list cur i n
        cur=$(current)
        mapfile -t list < <(names "$(mode_of "$cur")")
        n=''${#list[@]}
        for i in "''${!list[@]}"; do [ "''${list[$i]}" = "$cur" ] && break; done
        THEME_NOTIFY=1 apply "''${list[$(( (i + $1 + n) % n ))]}"
      }

      # One switch at a time, so fast scrolling doesn't pile up.
      # Light <-> dark: back to the last theme used in the other mode.
      toggle() {
        local m t
        m=$(other "$(mode_of "$(current)")")
        t=$(cat "$sdir/theme-last-$m" 2>/dev/null || names "$m" | head -1)
        THEME_NOTIFY=1 apply "$t"
      }

      # Menu rows: name, subtitle, thumbnail. Current mode first.
      rows() {
        local cur m name mode dir sub
        cur=$(current)
        m=$(mode_of "$cur")
        { awk -F'|' -v m="$m" '$2 == m' <<<"$themes"; awk -F'|' -v m="$m" '$2 != m' <<<"$themes"; } |
          while IFS='|' read -r name mode _ _ dir; do
            sub=''${mode^}
            [ "$name" = "$cur" ] && sub="$sub · current"
            printf '%s\t%s\t%s\n' "$name" "$sub" "$( [ -e "$thumbs/''${dir##*/}.png" ] && echo "$thumbs/''${dir##*/}.png")"
          done
      }

      case "''${1:-}" in
        list) cut -d'|' -f1,2 <<<"$themes" | tr '|' '\t'; exit ;;
        rows) rows; exit ;;
        current) current; exit ;;
        "") exec sysmenu style.theme ;;
      esac

      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/theme.lock"
      flock -n 9 || exit 0

      case "''${1:-}" in
        next) step 1 ;;
        prev) step -1 ;;
        toggle) toggle ;;
        *) apply "$*" ;;
      esac
    '';
  };
in
{
  home.packages = [ theme ];

  # Custom palettes for the "custom" source.
  xdg.configFile = builtins.listToAttrs (
    map (f: {
      name = "noctalia/palettes/${f}";
      value.source = ./palettes + "/${f}";
    }) (builtins.attrNames (builtins.readDir ./palettes))
  );
}
