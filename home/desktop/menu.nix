# Two launcher menus: sysmenu (capture, tools, toggles, style, setup, power)
# and keybinds (searchable list of my shortcuts). The keys are set in the dotfiles.
# The System menu's rows live in menu-entries.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  entries = config.gav.sysmenu.entries;
  parentOf = id: lib.concatStringsSep "." (lib.init (lib.splitString "." id));
  # Sections and lists open in the launcher; everything else runs.
  isMenu = e: e.list != null || lib.any (c: parentOf c.id == e.id) entries;
  conditional = lib.filter (e: e.when != null) entries;
  arm = pat: body: ''
    ${lib.escapeShellArg pat})
    ${body}
    ;;
  '';

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
      n() { noctalia msg "$@"; }
      web() { xdg-open "$1" >/dev/null 2>&1 & }
      # Runs a fish command in the floating terminal and waits before closing.
      term() {
        ghostty --gtk-single-instance=false --class=com.ghostty.floating \
          -e fish -c "$1; read -P 'Done. Enter to close '" &
      }
      # Terminal apps, each in its own window.
      tui() { ghostty --gtk-single-instance=false "$@" & }
      # Let the launcher close before grabbing the screen.
      settle() { sleep 0.3; }
      # Record the screen; audio per `recaudio` (Capture → Recording audio). Ctrl-C finishes the file.
      record() {
        local dir=$HOME/Videos/Recordings audio=()
        mkdir -p "$dir"
        case "$(recaudio current)" in
          Mic) audio=(-a default_input) ;;
          Both) audio=(-a "default_output|default_input") ;;
          None) ;;
          *) audio=(-a default_output) ;;
        esac
        gpu-screen-recorder "$@" "''${audio[@]}" -o "$dir/$(date +%F_%H-%M-%S).mp4" >/dev/null 2>&1 &
        notify-send -a Recorder "Recording" "Stop it from System menu → Capture."
      }
      recording() { pgrep -f 'gpu-screen-recorder -w' >/dev/null; }

      run_entry() {
        case "$1" in
          ${lib.concatMapStrings (
            e:
            arm e.id (
              if isMenu e then ''exec noctalia msg panel-toggle launcher "/sys ${e.id} "'' else e.run
            )
          ) (lib.filter (e: isMenu e || e.run != null) entries)}
          *) echo "sysmenu: no entry '$1'" >&2; exit 1 ;;
        esac
      }

      # Rows with a `when` test, and the tests.
      conditional=(${lib.escapeShellArgs (map (e: e.id) conditional)})
      shows() {
        case "$1" in
          ${lib.concatMapStrings (e: arm e.id e.when) conditional}
          *) true ;;
        esac
      }

      # `sysmenu capture 'Region to clipboard'` finds the row by its title.
      by_title() {
        case "$1" in
          ${lib.concatMapStrings (e: arm "${parentOf e.id}/${e.title}" "echo ${e.id}") entries}
          *) echo "$1" ;;
        esac
      }

      # `sysmenu` opens the icon menu (Noctalia plugin gav/sysmenu); `sysmenu <id>`
      # opens a section or runs a row; `sysmenu hidden` lists rows to hide now.
      case "''${1:-}" in
        "") exec noctalia msg panel-toggle launcher "/sys " ;;
        apps | Apps) exec noctalia msg panel-open launcher ;;
        run) run_entry "''${2:?entry id}" ;;
        hidden) for id in "''${conditional[@]}"; do shows "$id" || echo "$id"; done ;;
        *)
          id=''${1,,}
          [ -z "''${2:-}" ] || id=$(by_title "$id/$2")
          run_entry "$id"
          ;;
      esac
    '';
  };
in
{
  options.gav.sysmenu.entries = lib.mkOption {
    description = "System menu rows, in order (see menu-entries.nix).";
    default = [ ];
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          id = lib.mkOption { type = lib.types.str; };
          title = lib.mkOption { type = lib.types.str; };
          glyph = lib.mkOption {
            type = lib.types.str;
            default = "point";
          };
          sub = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          run = lib.mkOption {
            type = lib.types.nullOr lib.types.lines;
            default = null;
          };
          list = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          when = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      }
    );
  };

  config = {
    gav.sysmenu.entries = import ./menu-entries.nix;

    home.packages = [
      sysmenu
      keybinds
      pkgs.dua
      pkgs.wiremix
    ];

    # Enabled via [plugins] in noctalia/config.toml.
    xdg.dataFile."noctalia/plugins/sysmenu".source = ./noctalia/plugins/sysmenu;

    # What the plugin draws; read each time the menu opens.
    xdg.configFile."sysmenu/menu.json".text = builtins.toJSON (
      map (
        e:
        lib.filterAttrs (_: v: v != null) {
          inherit (e)
            id
            title
            glyph
            sub
            list
            ;
          parent = parentOf e.id;
          menu = isMenu e;
          when = e.when != null;
        }
      ) entries
    );
  };
}
