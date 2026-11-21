# The `font` command: one coding font across apps. The list is font-list.nix;
# modules can hook font switches via gav.hooks.onFontChange.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  fonts = import ./font-list.nix pkgs;
  fontHooks = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: body: ''
      # hook: ${name}
      (
        ${body}
      )
    '') config.gav.hooks.onFontChange
  );

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
      pkgs.libnotify
      pkgs.procps # pkill
      pkgs.python3
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
        local family
        family=$(grep -m1 "^$1|" <<<"$fonts" | cut -d'|' -f2 || true)
        [ -n "$family" ] || { echo "unknown font: $1" >&2; exit 1; }

        export FONT_FAMILY="$family" FONT_NAME="$1" CFG_DIR="$cfg"
        ${fontHooks}

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
  options.gav.hooks.onFontChange = lib.mkOption {
    description = "Shell hooks run when `font` switches (FONT_FAMILY, FONT_NAME, CFG_DIR).";
    type = lib.types.attrsOf lib.types.lines;
    default = { };
  };

  config = {
    gav.hooks.onFontChange = {
      # Ghostty includes ~/.config/ghostty/font; SIGUSR2 reloads open windows.
      ghostty = ''
        mkdir -p "$CFG_DIR/ghostty"
        printf 'font-family = %s\n' "$FONT_FAMILY" >"$CFG_DIR/ghostty/font"
        pkill -USR2 -f '^ghostty( |$)' || true
      '';

      noctalia = ''
        noctalia msg config-set shell.font_family "'$FONT_FAMILY'" >/dev/null
      '';

      # Update buffer_font_family in Zed's JSONC without disturbing comments.
      zed = ''
        zed="$CFG_DIR/zed/settings.json"
        if [ -w "$zed" ]; then
          python3 -I - "$zed" "$FONT_FAMILY" <<'PY'
import json, re, sys
path, fam = sys.argv[1], sys.argv[2]
txt = open(path).read()
val = json.dumps(fam)
if re.search(r'"buffer_font_family"\s*:', txt):
    out = re.sub(r'("buffer_font_family"\s*:\s*)"(?:\\.|[^"\\])*"', rf'\1{val}', txt, count=1)
else:
    out = re.sub(r'^([ \t]*"buffer_font_size"[^\n]*)$', rf'\1\n  "buffer_font_family": {val},', txt, count=1, flags=re.M)
if out != txt:
    open(path, "w").write(out)
PY
        fi
      '';

      # GTK apps' monospace font, keeping the size.
      gtk = ''
        size=$(dconf read /org/gnome/desktop/interface/monospace-font-name | grep -oE '[0-9.]+' | tail -1 || true)
        dconf write /org/gnome/desktop/interface/monospace-font-name "'$FONT_FAMILY ''${size:-10}'" || true
      '';

      # Everything else that asks for "monospace".
      fontconfig = ''
        mkdir -p "$CFG_DIR/fontconfig/conf.d"
        cat >"$CFG_DIR/fontconfig/conf.d/60-font-picker.conf" <<EOF
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <!-- Written by the font command. -->
        <fontconfig>
          <alias><family>monospace</family><prefer><family>$FONT_FAMILY</family></prefer></alias>
        </fontconfig>
        EOF
      '';
    };

    home.packages = [ font ];
  };
}
