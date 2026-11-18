# The `font` command: one coding font for the terminal, the Noctalia bar and
# launcher, Zed, GTK apps and anything that asks for "monospace". The list is
# font-list.nix; `font` alone opens it in the System menu with previews.
{ pkgs, lib, ... }:

let
  fonts = import ./font-list.nix pkgs;

  # "Aa" tile per font for the menu rows.
  previews =
    pkgs.runCommand "font-previews"
      {
        nativeBuildInputs = [
          pkgs.imagemagick
          pkgs.fontconfig
        ];
        FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = map (f: f.package) fonts; };
      }
      ''
        export HOME=$TMPDIR XDG_CACHE_HOME=$TMPDIR
        mkdir -p $out
        ${lib.concatMapStrings (f: ''
          fc-match -f '%{family}' ${lib.escapeShellArg "${f.family}:style=Regular"} | grep -qF ${lib.escapeShellArg f.family} \
            || { echo "font family not found: ${f.family}" >&2; exit 1; }
          magick -size 128x128 xc:none -fill '#26262b' -draw 'roundrectangle 0,0 127,127 26,26' \
            -font "$(fc-match -f '%{file}' ${lib.escapeShellArg "${f.family}:style=Regular"})" \
            -pointsize 62 -fill '#ececec' -gravity center -annotate +0+0 Aa \
            "$out"/${lib.escapeShellArg "${f.name}.png"}
        '') fonts}
      '';

  font = pkgs.writeShellApplication {
    name = "font";
    runtimeInputs = [
      pkgs.dconf
      pkgs.fontconfig # fc-list
      pkgs.gnused
      pkgs.libnotify
      pkgs.procps # pkill
    ];
    text = ''
      # name|font family
      fonts=${lib.escapeShellArg (lib.concatMapStringsSep "\n" (f: "${f.name}|${f.family}") fonts)}
      previews=${previews}
      cfg="''${XDG_CONFIG_HOME:-$HOME/.config}"
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/font-current"

      current() { cat "$state" 2>/dev/null || echo "JetBrains Mono"; }
      # Only fonts that are actually installed.
      names() {
        local name family
        while IFS='|' read -r name family; do
          fc-list -q "$family" && echo "$name"
        done <<<"$fonts"
      }

      # Menu rows: name, subtitle, preview image.
      rows() {
        local cur name
        cur=$(current)
        names | while read -r name; do
          printf '%s\t%s\t%s\n' "$name" "$([ "$name" = "$cur" ] && echo Current)" "$previews/$name.png"
        done
      }

      apply() {
        local family size
        family=$(grep -m1 "^$1|" <<<"$fonts" | cut -d'|' -f2 || true)
        [ -n "$family" ] || { echo "unknown font: $1" >&2; exit 1; }

        # Ghostty: its config includes this file; SIGUSR2 reloads open windows.
        mkdir -p "$cfg/ghostty"
        echo "font-family = $family" >"$cfg/ghostty/font"
        pkill -USR2 -f '^ghostty( |$)' || true

        noctalia msg config-set shell.font_family "'$family'" >/dev/null

        # Zed: settings.json allows trailing commas, so edit the line in place.
        zed="$cfg/zed/settings.json"
        if [ -w "$zed" ]; then
          if grep -q '"buffer_font_family"' "$zed"; then
            sed -i "s|\"buffer_font_family\": *\"[^\"]*\"|\"buffer_font_family\": \"$family\"|" "$zed"
          else
            sed -i "s|^\( *\)\"buffer_font_size\".*|&\n\1\"buffer_font_family\": \"$family\",|" "$zed"
          fi
        fi

        # GTK apps' monospace font, keeping the size.
        size=$(dconf read /org/gnome/desktop/interface/monospace-font-name | grep -oE '[0-9.]+' | tail -1 || true)
        dconf write /org/gnome/desktop/interface/monospace-font-name "'$family ''${size:-10}'" || true

        # Everything else that asks for "monospace".
        mkdir -p "$cfg/fontconfig/conf.d"
        cat >"$cfg/fontconfig/conf.d/60-font-picker.conf" <<EOF
      <?xml version="1.0"?>
      <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
      <!-- Written by the font command. -->
      <fontconfig>
        <alias><family>monospace</family><prefer><family>$family</family></prefer></alias>
      </fontconfig>
      EOF

        mkdir -p "''${state%/*}"
        echo "$1" >"$state"
        notify-send -a Font -t 2000 -i "$previews/$1.png" "Font" "$1"
      }

      case "''${1:-}" in
        list) names ;;
        rows) rows ;;
        current) current ;;
        "") exec sysmenu style.font ;;
        *) apply "$*" ;;
      esac
    '';
  };
in
{
  home.packages = [ font ];
}
