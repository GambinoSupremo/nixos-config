# theme: named looks (Noctalia palette + matching wallpaper folder).
# Wallpapers live in ~/Pictures/themes/<slug>; "Wallpaper" = colors from the wallpaper.
# Each theme is dark or light; `theme toggle` flips to the last one used in the other mode.
{ pkgs, ... }:

let
  # Fullscreen title card: the theme's name drawn in its new colours, then gone.
  intro = pkgs.writeShellScript "theme-intro" ''
    printf '\e[?25l\e[2J\e[H'
    name=$(cat "''${XDG_STATE_HOME:-$HOME/.local/state}/theme-current")
    stops=$(${pkgs.jq}/bin/jq -r '[.mPrimary, .mSecondary, .mTertiary] | map(ltrimstr("#")) | join(" ")' \
      "$HOME/.config/noctalia/colors.json")
    effects=(expand middleout slide wipe)
    # shellcheck disable=SC2086
    ${pkgs.figlet}/bin/figlet -f slant -C utf8 -w "$(stty size | cut -d' ' -f2)" "$name" \
      | ${pkgs.terminaltexteffects}/bin/tte --frame-rate 120 --canvas-width 0 --canvas-height 0 \
        --anchor-canvas c --anchor-text c --no-eol --no-restore-cursor \
        "''${effects[RANDOM % 4]}" --final-gradient-stops $stops
    sleep 0.7
  '';

  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.jq
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
      Lupine|light|custom|Lupine|themes/lupine
      Flexoki Light|light|custom|Flexoki-Light|themes/flexoki-light
      White|light|custom|White|themes/white'
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
        local colors=$HOME/.config/noctalia/colors.json before
        before=$(stat -c %Y.%s "$colors" 2>/dev/null || true)
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
        [ -n "''${THEME_INTRO:-}" ] && show_intro "$colors" "$before"
        # Login screen follows too, once the new wallpaper has landed.
        (sleep 3; noctalia msg greeter-sync >/dev/null 2>&1) 9>&- &
      }

      # Picker and light/dark only (not scrolling). Waits up to 1.5 s for Noctalia
      # to write the new colours, then opens the title card on the focused monitor.
      show_intro() {
        [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || return 0
        local i m
        for i in $(seq 15); do
          [ "$(stat -c %Y.%s "$1" 2>/dev/null || true)" != "$2" ] && break
          sleep 0.1
        done
        sleep 0.2
        m=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
        hyprctl dispatch "hl.dsp.exec_cmd(\"ghostty --gtk-single-instance=false --class=theme-intro --font-size=28 --confirm-close-surface=false -e ${intro}\", { monitor = \"$m\", fullscreen = true })" >/dev/null
      }

      # Step through the current mode's themes (wraps); bar button scroll and Super+Ctrl+T.
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
        THEME_INTRO=1 apply "$t"
      }

      # Picker shows one mode at a time; the last row flips to the other mode's list.
      pick() {
        local m=$1 cur sw choice
        cur=$(current)
        sw="→ $(other "$m") themes"
        choice=$( { names "$m" | sed "s/^$cur\$/$cur  ·  current/"; echo "$sw"; } \
          | noctalia dmenu -p "Theme ($m)" || true)
        case "$choice" in
          "") ;;
          "$sw") pick "$(other "$m")" ;;
          *) THEME_INTRO=1 apply "''${choice%  ·  current}" ;;
        esac
      }

      exec 9>"''${XDG_RUNTIME_DIR:-/tmp}/theme.lock"
      flock -n 9 || exit 0

      case "''${1:-}" in
        list) cut -d'|' -f1,2 <<<"$themes" | tr '|' '\t' ;;
        next) step 1 ;;
        prev) step -1 ;;
        toggle) toggle ;;
        current) current ;;
        "") pick "$(mode_of "$(current)")" ;;
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
