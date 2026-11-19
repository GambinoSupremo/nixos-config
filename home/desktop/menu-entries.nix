# The System menu, in order. To add a row, add a line:
#   id     "capture" is a section; "capture.region" sits inside it (any depth)
#   glyph  Tabler icon name (tabler.io/icons); sub = grey line under the title
#   run    shell to run. Helpers: n (noctalia msg), settle, web, term, tui, record
#   list   instead of run: a command with `<cmd> rows` and `<cmd> <name>` (font, theme)
#   when   shell test; the row only shows while it passes
# Other modules can add rows with gav.sysmenu.entries = [ ... ].
[
  { id = "learn"; title = "Learn"; glyph = "school"; sub = "Keybindings and docs"; }
  { id = "learn.keys"; title = "Keybindings"; glyph = "keyboard"; run = "keybinds"; }
  { id = "learn.hyprland"; title = "Hyprland wiki"; glyph = "world"; run = "web https://wiki.hypr.land"; }
  { id = "learn.nixos"; title = "NixOS options"; glyph = "book"; run = "web https://search.nixos.org/options"; }
  { id = "learn.hm"; title = "Home Manager options"; glyph = "book-2"; run = "web https://home-manager-options.extranix.com"; }
  { id = "learn.noctalia"; title = "Noctalia docs"; glyph = "sparkles"; run = "web https://noctalia.dev"; }

  { id = "capture"; title = "Capture"; glyph = "camera"; sub = "Screenshots, recording, text, QR codes"; }
  {
    id = "capture.stop";
    title = "Stop recording";
    glyph = "player-stop";
    when = "recording";
    run = ''
      pkill -INT -f 'gpu-screen-recorder -w'
      sleep 0.5 # let it finish writing
      file=$(find "$HOME/Videos/Recordings" -maxdepth 1 -name '*.mp4' -printf '%T@ %p\n' | sort -n | tail -1 | cut -d' ' -f2-)
      case "$(notify-send -a Recorder --action=open=Open --action=folder="Show folder" "Recording saved" "''${file##*/}")" in
        open) xdg-open "$file" ;;
        folder) xdg-open "''${file%/*}" ;;
      esac
    '';
  }
  { id = "capture.region"; title = "Region"; glyph = "screenshot"; run = "settle; n screenshot-region"; }
  { id = "capture.window"; title = "Window"; glyph = "app-window"; run = "settle; n screenshot-window"; }
  { id = "capture.screen"; title = "Screen"; glyph = "device-desktop"; run = "settle; n screenshot-fullscreen"; }
  { id = "capture.draw"; title = "Draw on screen"; glyph = "pencil"; run = "settle; n annotate"; }
  {
    id = "capture.clip";
    title = "Region to clipboard";
    glyph = "clipboard";
    run = ''
      settle
      area=$(slurp) || exit 0
      grim -g "$area" - | wl-copy
      # Edit opens the copy in Satty (annotate, then copy or save from there).
      [ "$(notify-send -a Screenshot --action=edit=Edit "Copied to clipboard" "Region screenshot")" = edit ] \
        && wl-paste | satty --filename -
    '';
  }
  {
    id = "capture.qr";
    title = "Scan QR code";
    glyph = "qrcode";
    run = ''
      settle
      area=$(slurp) || exit 0
      if code=$(grim -g "$area" - | zbarimg -q --raw -); then
        printf '%s' "$code" | wl-copy
        notify-send -a "QR code" "Copied" "$code"
      else
        notify-send -a "QR code" "No QR code found"
      fi
    '';
  }
  { id = "capture.rec-region"; title = "Record region"; glyph = "player-record"; run = "settle; area=$(slurp -f '%wx%h+%x+%y') || exit 0; record -w region -region \"$area\""; }
  { id = "capture.rec-screen"; title = "Record screen"; glyph = "screen-share"; run = "settle; output=$(slurp -o -f '%o') || exit 0; record -w \"$output\""; }
  { id = "capture.audio"; title = "Recording audio"; glyph = "microphone"; sub = "Desktop, mic, both or none"; list = "recaudio"; }
  { id = "capture.webcam"; title = "Webcam bubble"; glyph = "camera-selfie"; run = "webcam &"; }
  { id = "capture.fix"; title = "Fix a recording"; glyph = "cut"; sub = "Trim or even out volume"; run = "media-fix"; }
  { id = "capture.convert"; title = "Shrink or convert"; glyph = "file-export"; sub = "Videos, GIFs, images"; run = "convert-file"; }
  { id = "capture.ocr"; title = "Copy text from screen"; glyph = "text-scan-2"; run = "settle; ocr"; }
  { id = "capture.color"; title = "Color picker"; glyph = "color-picker"; run = "settle; hyprpicker -a"; }

  { id = "tools"; title = "Tools"; glyph = "tools"; sub = "btop, lazygit, dua, wiremix"; }
  { id = "tools.btop"; title = "System monitor (btop)"; glyph = "cpu"; run = "tui -e btop"; }
  { id = "tools.git"; title = "Git (lazygit)"; glyph = "git-branch"; run = "tui --working-directory=\"$HOME/nixos-config\" -e lazygit"; }
  { id = "tools.dua"; title = "Disk usage (dua)"; glyph = "chart-pie"; run = "tui --working-directory=\"$HOME\" -e dua interactive"; }
  { id = "tools.mixer"; title = "Audio mixer (wiremix)"; glyph = "volume"; run = "tui --class=com.ghostty.floating -e wiremix"; }

  { id = "toggle"; title = "Toggle"; glyph = "toggle-left"; sub = "Night light, do not disturb, stay awake"; }
  { id = "toggle.nightlight"; title = "Night light"; glyph = "moon-stars"; run = "n nightlight-force-toggle"; }
  { id = "toggle.dnd"; title = "Do not disturb"; glyph = "bell-off"; run = "n notification-dnd-toggle"; }
  { id = "toggle.awake"; title = "Stay awake"; glyph = "coffee"; run = "n caffeine-toggle"; }
  { id = "toggle.bar"; title = "Bar"; glyph = "layout-navbar"; run = "n bar-toggle"; }
  { id = "toggle.bluetooth"; title = "Bluetooth"; glyph = "bluetooth"; run = "n bluetooth-toggle"; }

  { id = "style"; title = "Style"; glyph = "palette"; sub = "Theme, font, wallpaper, light/dark"; }
  { id = "style.theme"; title = "Theme"; glyph = "brush"; list = "theme"; }
  { id = "style.add"; title = "Add theme from GitHub"; glyph = "brand-github"; run = "theme-install"; }
  { id = "style.font"; title = "Font"; glyph = "typography"; list = "font"; }
  { id = "style.wallpaper"; title = "Wallpaper"; glyph = "photo"; run = "n panel-open wallpaper"; }
  { id = "style.random"; title = "Random wallpaper"; glyph = "arrows-shuffle"; run = "n wallpaper-random"; }
  { id = "style.mode"; title = "Light/dark"; glyph = "sun-moon"; run = "theme toggle"; }
  { id = "style.settings"; title = "Noctalia settings"; glyph = "settings"; run = "n settings-open"; }

  { id = "setup"; title = "Setup"; glyph = "adjustments"; sub = "Audio, configs, web apps, restarts"; }
  { id = "setup.audio"; title = "Audio"; glyph = "volume"; run = "n panel-open control-center audio"; }
  { id = "setup.webapp"; title = "Add web app"; glyph = "world-plus"; run = "webapp-add"; }
  { id = "setup.nixos"; title = "Edit nixos-config"; glyph = "folder-cog"; run = "zeditor \"$HOME/nixos-config\""; }
  { id = "setup.dotfiles"; title = "Edit dotfiles"; glyph = "brand-git"; run = "zeditor \"$HOME/Projects/dotfiles\""; }
  { id = "setup.noctalia"; title = "Restart Noctalia"; glyph = "reload"; run = "systemctl --user restart noctalia.service"; }
  { id = "setup.hyprland"; title = "Reload Hyprland"; glyph = "refresh"; run = "hyprctl reload"; }

  { id = "update"; title = "Update"; glyph = "package"; sub = "apply, update"; }
  { id = "update.apply"; title = "Apply config"; glyph = "wand"; run = "term apply"; }
  { id = "update.inputs"; title = "Update inputs"; glyph = "cloud-download"; run = "term update"; }

  { id = "system"; title = "System"; glyph = "power"; sub = "Lock, suspend, reboot, shut down"; }
  { id = "system.screensaver"; title = "Screensaver"; glyph = "device-tv"; run = "settle; screensaver"; }
  { id = "system.lock"; title = "Lock"; glyph = "lock"; run = "n session lock"; }
  { id = "system.suspend"; title = "Suspend"; glyph = "zzz"; run = "n session suspend"; }
  { id = "system.logout"; title = "Log out"; glyph = "logout"; run = "n session logout"; }
  { id = "system.reboot"; title = "Reboot"; glyph = "rotate-clockwise"; run = "n session reboot"; }
  { id = "system.uefi"; title = "Reboot to UEFI"; glyph = "settings"; run = "n session reboot-uefi"; }
  { id = "system.shutdown"; title = "Shut down"; glyph = "power"; run = "n session shutdown"; }
]
