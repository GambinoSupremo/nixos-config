# The `font` command: one coding font for the terminal, the Noctalia bar and
# launcher, Zed, and apps that ask for "monospace". The fonts are installed in
# nixos/base/desktop.nix.
{ pkgs, ... }:

let
  font = pkgs.writeShellApplication {
    name = "font";
    runtimeInputs = [
      pkgs.fontconfig # fc-list
      pkgs.gnused
      pkgs.libnotify
      pkgs.procps # pkill
    ];
    text = ''
      # name|font family
      fonts='JetBrains Mono|JetBrainsMono Nerd Font
      Cascadia Mono|CaskaydiaMono Nerd Font
      Fira Code|FiraCode Nerd Font
      Iosevka|IosevkaTerm Nerd Font
      Geist Mono|GeistMono Nerd Font
      Commit Mono|CommitMono Nerd Font
      Victor Mono|VictorMono Nerd Font
      Hack|Hack Nerd Font
      Meslo|MesloLGM Nerd Font
      Departure Mono|DepartureMono Nerd Font'
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

      apply() {
        local family
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
        notify-send -a Font -t 2000 "Font" "$1"
      }

      pick() {
        local cur choice
        cur=$(current)
        choice=$(names | sed "s/^$cur\$/$cur  ·  current/" | noctalia dmenu -p "Font" || true)
        [ -z "$choice" ] || apply "''${choice%  ·  current}"
      }

      case "''${1:-}" in
        list) names ;;
        current) current ;;
        "") pick ;;
        *) apply "$*" ;;
      esac
    '';
  };
in
{
  home.packages = [ font ];
}
