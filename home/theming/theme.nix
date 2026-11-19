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
      # Themes added from GitHub links (theme-install).
      [ -s "$sdir/theme-added" ] && themes+=$'\n'$(cat "$sdir/theme-added")
      added_thumbs="''${XDG_CACHE_HOME:-$HOME/.cache}/theme-thumbs"

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
        local cur m name mode dir sub thumb t
        cur=$(current)
        m=$(mode_of "$cur")
        { awk -F'|' -v m="$m" '$2 == m' <<<"$themes"; awk -F'|' -v m="$m" '$2 != m' <<<"$themes"; } |
          while IFS='|' read -r name mode _ _ dir; do
            sub=''${mode^}
            [ "$name" = "$cur" ] && sub="$sub · current"
            thumb=""
            for t in "$added_thumbs/''${dir##*/}.png" "$thumbs/''${dir##*/}.png"; do [ -e "$t" ] && thumb=$t && break; done
            printf '%s\t%s\t%s\n' "$name" "$sub" "$thumb"
          done
      }

      case "''${1:-}" in
        list) cut -d'|' -f1,2 <<<"$themes" | tr '|' '\t'; exit ;;
        rows) rows; exit ;;
        current) current; exit ;;
        install) shift; exec theme-install "$@" ;;
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

  # `theme install <github link>`: palette from its colors.toml (or
  # alacritty.toml), wallpapers from backgrounds/, then switches to it.
  theme-install = pkgs.writeShellApplication {
    name = "theme-install";
    runtimeInputs = [
      pkgs.git
      pkgs.python3
      pkgs.imagemagick
      pkgs.zenity
      pkgs.wl-clipboard
      pkgs.libnotify
    ];
    text = ''
      say() { notify-send -a Theme "$@"; }
      url=''${1:-}
      if [ -z "$url" ]; then
        clip=$(wl-paste -n 2>/dev/null || true)
        [[ $clip == https://github.com/* ]] || clip=""
        url=$(zenity --entry --title="Add theme" --text="GitHub link of the theme" --entry-text="$clip" --width=480) || exit 0
      fi
      url=''${url%/}; url=''${url%.git}
      if ! [[ $url =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
        say "Needs a GitHub link" "e.g. https://github.com/someone/some-theme"; exit 1
      fi
      guess=$(sed -E 's/[-_]theme$//I; s/[-_]+/ /g; s/\b(.)/\u\1/g' <<<"''${url##*/}")
      name=''${2:-$(zenity --entry --title="Add theme" --text="Name" --entry-text="$guess")} || exit 0
      name=$(tr -d '|' <<<"$name")
      [ -n "$name" ] || exit 0
      slug=$(tr '[:upper:] ' '[:lower:]-' <<<"$name" | tr -cd 'a-z0-9-')
      pal=$(tr ' ' '-' <<<"$name" | tr -cd 'A-Za-z0-9-')
      sdir="''${XDG_STATE_HOME:-$HOME/.local/state}"
      added="$sdir/theme-added"
      if theme list | cut -f1 | grep -qxF "$name" && ! grep -q "^$name|" "$added" 2>/dev/null; then
        say "$name already exists" "Pick another name."; exit 1
      fi

      work=$(mktemp -d); trap 'rm -rf "$work"' EXIT
      git clone -q --depth 1 "$url" "$work/src" || { say "Couldn't download" "$url"; exit 1; }
      python3 -I ${./theme-palette.py} "$work/src" >"$work/palette.json" || { say "No colors found" "$url has no colors.toml or alacritty.toml"; exit 1; }
      mkdir -p "$HOME/.config/noctalia/palettes"
      cp "$work/palette.json" "$HOME/.config/noctalia/palettes/$pal.json"
      mode=dark; [ -e "$work/src/light.mode" ] && mode=light

      walls="$HOME/Pictures/theme-added/$slug"
      rm -rf "$walls"; mkdir -p "$walls"
      [ -d "$work/src/backgrounds" ] && find "$work/src/backgrounds" -maxdepth 1 -type f \
        \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -exec cp -t "$walls" {} +
      tdir="''${XDG_CACHE_HOME:-$HOME/.cache}/theme-thumbs"; mkdir -p "$tdir"
      img=$(find "$walls" -type f | sort | head -1)
      [ -n "$img" ] && magick "$img" -resize 128x128^ -gravity center -extent 128x128 \
        \( -size 128x128 xc:none -fill white -draw 'roundrectangle 0,0 127,127 26,26' \) \
        -compose DstIn -composite "$tdir/$slug.png"

      mkdir -p "$sdir"
      { grep -v "^$name|" "$added" 2>/dev/null || true; echo "$name|$mode|custom|$pal|theme-added/$slug"; } >"$added.new"
      mv "$added.new" "$added"
      theme "$name"
      say "$name added" "In the Style menu with your other themes."
    '';
  };
in
{
  home.packages = [
    theme
    theme-install
  ];

  # Custom palettes for the "custom" source.
  xdg.configFile = builtins.listToAttrs (
    map (f: {
      name = "noctalia/palettes/${f}";
      value.source = ./palettes + "/${f}";
    }) (builtins.attrNames (builtins.readDir ./palettes))
  );
}
