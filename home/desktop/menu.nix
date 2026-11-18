# Two launcher menus: sysmenu (capture, tools, toggles, style, setup, power)
# and keybinds (searchable list of my shortcuts). The keys are set in the dotfiles.
{ pkgs, ... }:

let
  keybinds = pkgs.writeShellApplication {
    name = "keybinds";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      list() {
        if [ -n "''${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
          # Only binds with a description (hypr/bind.lua sets them).
          hyprctl binds -j | jq -r '
            def bit($n): ((.modmask / $n) | floor) % 2 == 1;
            .[] | select(.has_description) | .description as $d
            | [ (if bit(64) then "SUPER" else empty end), (if bit(4) then "CTRL" else empty end),
                (if bit(8) then "ALT" else empty end), (if bit(1) then "SHIFT" else empty end), .key ]
            | "\($d)  ·  \(join(" + "))"'
        elif [ -n "''${NIRI_SOCKET:-}" ]; then
          exec niri msg action show-hotkey-overlay
        else
          sed -n 's/^bind=\([^,]*\),\([^,]*\),\(.*\)$/\3  ·  \1 + \2/p' "$HOME/.config/mango/bind.conf" | sed 's/,$//'
        fi
      }
      list | noctalia dmenu -p "Keybindings" >/dev/null || true
    '';
  };

  sysmenu = pkgs.writeShellApplication {
    name = "sysmenu";
    runtimeInputs = [
      keybinds
      pkgs.grim
      pkgs.slurp
      pkgs.wl-clipboard
      pkgs.hyprpicker
      pkgs.xdg-utils
      pkgs.zbar
      pkgs.libnotify
      pkgs.procps
    ];
    text = ''
      pick() { local p=$1; shift; printf '%s\n' "$@" | noctalia dmenu -p "$p" || true; }
      n() { noctalia msg "$@"; }
      web() { xdg-open "$1" >/dev/null 2>&1 & }
      # Runs a fish command in the floating terminal and waits before closing.
      term() {
        ghostty --gtk-single-instance=false --class=com.ghostty.floating \
          -e fish -c "$1; read -P 'Done. Enter to close '" &
      }
      # Let the launcher close before grabbing the screen.
      settle() { sleep 0.3; }

      learn() {
        case ''${1:-$(pick Learn Keybindings "Hyprland wiki" "NixOS options" "Home Manager options" "Noctalia docs")} in
          Keybindings) keybinds ;;
          "Hyprland wiki") web https://wiki.hypr.land ;;
          "NixOS options") web https://search.nixos.org/options ;;
          "Home Manager options") web https://home-manager-options.extranix.com ;;
          "Noctalia docs") web https://noctalia.dev ;;
        esac
      }

      # Record the screen with desktop audio. Ctrl-C finishes the file.
      record() {
        local dir=$HOME/Videos/Recordings
        mkdir -p "$dir"
        gpu-screen-recorder "$@" -a default_output -o "$dir/$(date +%F_%H-%M-%S).mp4" >/dev/null 2>&1 &
        notify-send -a Recorder "Recording" "Stop it from System menu → Capture."
      }
      recording() { pgrep -f 'gpu-screen-recorder -w' >/dev/null; }

      capture() {
        local opts=(Region Window Screen "Draw on screen" "Region to clipboard" "Scan QR code" "Record region" "Record screen" "Color picker")
        recording && opts=("Stop recording" "''${opts[@]}")
        case ''${1:-$(pick Capture "''${opts[@]}")} in
          Region) settle; n screenshot-region ;;
          Window) settle; n screenshot-window ;;
          Screen) settle; n screenshot-fullscreen ;;
          "Draw on screen") settle; n annotate ;;
          "Region to clipboard")
            settle
            area=$(slurp) || exit 0
            grim -g "$area" - | wl-copy
            # Edit opens the copy in Satty (annotate, then copy or save from there).
            [ "$(notify-send -a Screenshot --action=edit=Edit "Copied to clipboard" "Region screenshot")" = edit ] \
              && wl-paste | satty --filename -
            ;;
          "Scan QR code")
            settle
            area=$(slurp) || exit 0
            if code=$(grim -g "$area" - | zbarimg -q --raw -); then
              printf '%s' "$code" | wl-copy
              notify-send -a "QR code" "Copied" "$code"
            else
              notify-send -a "QR code" "No QR code found"
            fi
            ;;
          "Record region") settle; area=$(slurp -f '%wx%h+%x+%y') || exit 0; record -w region -region "$area" ;;
          "Record screen") settle; output=$(slurp -o -f '%o') || exit 0; record -w "$output" ;;
          "Stop recording")
            pkill -INT -f 'gpu-screen-recorder -w'
            sleep 0.5 # let it finish writing
            file=$(find "$HOME/Videos/Recordings" -maxdepth 1 -name '*.mp4' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
            case "$(notify-send -a Recorder --action=open=Open --action=folder="Show folder" "Recording saved" "''${file##*/}")" in
              open) xdg-open "$file" ;;
              folder) xdg-open "''${file%/*}" ;;
            esac
            ;;
          "Color picker") settle; hyprpicker -a ;;
        esac
      }

      # Terminal apps, each in its own window.
      tui() { ghostty --gtk-single-instance=false "$@" & }
      tools() {
        case ''${1:-$(pick Tools "System monitor (btop)" "Git (lazygit)" "Disk usage (dua)" "Audio mixer (wiremix)")} in
          "System monitor (btop)") tui -e btop ;;
          "Git (lazygit)") tui --working-directory="$HOME/nixos-config" -e lazygit ;;
          "Disk usage (dua)") tui --working-directory="$HOME" -e dua interactive ;;
          "Audio mixer (wiremix)") tui --class=com.ghostty.floating -e wiremix ;;
        esac
      }

      toggle() {
        case ''${1:-$(pick Toggle "Night light" "Do not disturb" "Stay awake" Bar Bluetooth)} in
          "Night light") n nightlight-force-toggle ;;
          "Do not disturb") n notification-dnd-toggle ;;
          "Stay awake") n caffeine-toggle ;;
          Bar) n bar-toggle ;;
          Bluetooth) n bluetooth-toggle ;;
        esac
      }

      style() {
        case ''${1:-$(pick Style Theme Font Wallpaper "Random wallpaper" "Light/dark" "Noctalia settings")} in
          Theme) theme ;;
          Font) font ;;
          Wallpaper) n panel-open wallpaper ;;
          "Light/dark") theme toggle ;;
          "Random wallpaper") n wallpaper-random ;;
          "Noctalia settings") n settings-open ;;
        esac
      }

      setup() {
        case ''${1:-$(pick Setup Audio "Edit nixos-config" "Edit dotfiles" "Restart Noctalia" "Reload Hyprland")} in
          Audio) n panel-open control-center audio ;;
          "Edit nixos-config") zeditor "$HOME/nixos-config" ;;
          "Edit dotfiles") zeditor "$HOME/Projects/dotfiles" ;;
          "Restart Noctalia") systemctl --user restart noctalia.service ;;
          "Reload Hyprland") hyprctl reload ;;
        esac
      }

      update() {
        case ''${1:-$(pick Update "Apply config" "Update inputs")} in
          "Apply config") term apply ;;
          "Update inputs") term update ;;
        esac
      }

      system() {
        case ''${1:-$(pick System Screensaver Lock Suspend "Log out" Reboot "Reboot to UEFI" "Shut down")} in
          Screensaver) settle; screensaver ;;
          Lock) n session lock ;;
          Suspend) n session suspend ;;
          "Log out") n session logout ;;
          Reboot) n session reboot ;;
          "Reboot to UEFI") n session reboot-uefi ;;
          "Shut down") n session shutdown ;;
        esac
      }

      # Extra menu entries, one "Label<tab>command[<tab>icon]" per line.
      declare -A extras=()
      extra_file=$HOME/.config/sysmenu/extra
      if [ -r "$extra_file" ]; then
        while IFS=$'\t' read -r label command _glyph; do
          extras[$label]=$command
        done <"$extra_file"
      fi

      # `sysmenu` alone opens the icon menu (Noctalia plugin gav/sysmenu).
      # `sysmenu <section> [item]` opens one section or runs one entry.
      item=''${2:-}
      section=''${1:-}
      section=''${section,,}
      case "$section" in
        learn | capture | tools | toggle | style | setup | update | system)
          [ -n "$item" ] || exec noctalia msg panel-toggle launcher "/sys $section " ;;
      esac
      case "''${1:-}" in
        "") n panel-toggle launcher "/sys " ;;
        Apps | apps) n panel-open launcher ;;
        Learn | learn) learn "$item" ;;
        Capture | capture) capture "$item" ;;
        Tools | tools) tools "$item" ;;
        Toggle | toggle) toggle "$item" ;;
        Style | style) style "$item" ;;
        Setup | setup) setup "$item" ;;
        Update | update) update "$item" ;;
        System | system) system "$item" ;;
        *) [ -z "''${extras[$1]:-}" ] || exec sh -c "''${extras[$1]}" ;;
      esac
    '';
  };
in
{
  home.packages = [
    sysmenu
    keybinds
    pkgs.dua
    pkgs.wiremix
  ];

  # Enabled via [plugins] in noctalia/config.toml.
  xdg.dataFile."noctalia/plugins/sysmenu".source = ./noctalia/plugins/sysmenu;
}
