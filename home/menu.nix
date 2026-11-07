# sysmenu: a nested system menu (capture, toggles, style, setup, power) in Noctalia's launcher.
# keybinds: searchable list of the live compositor binds. Both are bound in the dotfiles.
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
        case $(pick Learn Keybindings "Hyprland wiki" "NixOS options" "Home Manager options" "Noctalia docs") in
          Keybindings) keybinds ;;
          "Hyprland wiki") web https://wiki.hypr.land ;;
          "NixOS options") web https://search.nixos.org/options ;;
          "Home Manager options") web https://home-manager-options.extranix.com ;;
          "Noctalia docs") web https://noctalia.dev ;;
        esac
      }

      capture() {
        case $(pick Capture Region Window Screen "Draw on screen" "Region to clipboard" "Color picker") in
          Region) settle; n screenshot-region ;;
          Window) settle; n screenshot-window ;;
          Screen) settle; n screenshot-fullscreen ;;
          "Draw on screen") settle; n annotate ;;
          "Region to clipboard") settle; grim -g "$(slurp)" - | wl-copy ;;
          "Color picker") settle; hyprpicker -a ;;
        esac
      }

      toggle() {
        case $(pick Toggle "Night light" "Do not disturb" "Stay awake" Bar Bluetooth) in
          "Night light") n nightlight-force-toggle ;;
          "Do not disturb") n notification-dnd-toggle ;;
          "Stay awake") n caffeine-toggle ;;
          Bar) n bar-toggle ;;
          Bluetooth) n bluetooth-toggle ;;
        esac
      }

      style() {
        case $(pick Style Theme Wallpaper "Random wallpaper" "Light/dark" "Noctalia settings") in
          Theme) theme ;;
          Wallpaper) n panel-open wallpaper ;;
          "Light/dark") n theme-mode-toggle ;;
          "Random wallpaper") n wallpaper-random ;;
          "Noctalia settings") n settings-open ;;
        esac
      }

      setup() {
        case $(pick Setup Audio "Edit nixos-config" "Edit dotfiles" "Restart Noctalia" "Reload Hyprland") in
          Audio) n panel-open control-center audio ;;
          "Edit nixos-config") zeditor "$HOME/nixos-config" ;;
          "Edit dotfiles") zeditor "$HOME/Projects/dotfiles" ;;
          "Restart Noctalia") systemctl --user restart noctalia.service ;;
          "Reload Hyprland") hyprctl reload ;;
        esac
      }

      update() {
        case $(pick Update "Apply config" "Update inputs") in
          "Apply config") term apply ;;
          "Update inputs") term update ;;
        esac
      }

      system() {
        case $(pick System Lock Suspend "Log out" Reboot "Reboot to UEFI" "Shut down") in
          Lock) n session lock ;;
          Suspend) n session suspend ;;
          "Log out") n session logout ;;
          Reboot) n session reboot ;;
          "Reboot to UEFI") n session reboot-uefi ;;
          "Shut down") n session shutdown ;;
        esac
      }

      # `sysmenu <section>` opens a section directly.
      case "''${1:-$(pick Menu Apps Learn Capture Toggle Style Setup Update System)}" in
        Apps | apps) n panel-open launcher ;;
        Learn | learn) learn ;;
        Capture | capture) capture ;;
        Toggle | toggle) toggle ;;
        Style | style) style ;;
        Setup | setup) setup ;;
        Update | update) update ;;
        System | system) system ;;
      esac
    '';
  };
in
{
  home.packages = [
    sysmenu
    keybinds
  ];
}
