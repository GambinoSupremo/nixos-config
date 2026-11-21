# Screen helpers used by the System menu and keys: zoom, OCR, webcam bubble,
# recording audio choice, recording cleanup and file shrink/convert.
{ pkgs, ... }:

let
  zoom = pkgs.writeShellApplication {
    name = "zoom";
    runtimeInputs = [ pkgs.jq ];
    text = ''
      cur=$(hyprctl getoption cursor:zoom_factor -j | jq '.float')
      case "''${1:-in}" in
        in) new=$(jq -n "[$cur * 1.5, 8] | min") ;;
        out) new=$(jq -n "[$cur / 1.5, 1] | max") ;;
        *) new=1 ;;
      esac
      hyprctl eval "hl.config({ cursor = { zoom_factor = $new } })" >/dev/null
    '';
  };

  ocr = pkgs.writeShellApplication {
    name = "ocr";
    runtimeInputs = [
      pkgs.grim
      pkgs.slurp
      pkgs.tesseract
      pkgs.wl-clipboard
      pkgs.libnotify
    ];
    text = ''
      area=$(slurp) || exit 0
      text=$(grim -g "$area" - | tesseract - - 2>/dev/null)
      if [ -n "''${text//[[:space:]]/}" ]; then
        printf '%s' "$text" | wl-copy
        notify-send -a "Copy text" "Copied" "$text"
      else
        notify-send -a "Copy text" "No text found"
      fi
    '';
  };

  # Which audio recordings get; read by sysmenu's record().
  recaudio = pkgs.writeShellApplication {
    name = "recaudio";
    runtimeInputs = [ pkgs.libnotify ];
    text = ''
      state=''${XDG_STATE_HOME:-$HOME/.local/state}/recaudio
      cur=$(cat "$state" 2>/dev/null || echo Desktop)
      case "''${1:-}" in
        rows)
          for o in Desktop Mic Both None; do
            printf '%s\t%s\t\n' "$o" "$([ "$o" = "$cur" ] && echo Current)"
          done ;;
        current) echo "$cur" ;;
        Desktop | Mic | Both | None)
          mkdir -p "''${state%/*}"; echo "$1" >"$state"
          notify-send -a Recorder -t 2000 "Recording audio" "$1" ;;
        *) echo "usage: recaudio rows|current|Desktop|Mic|Both|None" >&2; exit 1 ;;
      esac
    '';
  };

  webcam = pkgs.writeShellApplication {
    name = "webcam";
    runtimeInputs = [
      pkgs.mpv
      pkgs.procps
    ];
    text = ''
      # Toggle: a second press closes it.
      pkill -f 'wayland-app-id=webcam-bubble' && exit 0
      exec mpv av://v4l2:/dev/video0 --wayland-app-id=webcam-bubble --profile=low-latency \
        --untimed --no-osc --no-audio --osd-level=0 --no-input-default-bindings
    '';
  };

  media-fix = pkgs.writeShellApplication {
    name = "media-fix";
    runtimeInputs = [
      pkgs.ffmpeg
      pkgs.losslesscut-bin
      pkgs.libnotify
    ];
    text = builtins.readFile ./capture-tools/media-fix.sh;
  };

  convert-file = pkgs.writeShellApplication {
    name = "convert-file";
    runtimeInputs = [
      pkgs.ffmpeg
      pkgs.imagemagick
      pkgs.libnotify
    ];
    text = builtins.readFile ./capture-tools/convert-file.sh;
  };

  hypr-toggle = pkgs.writeShellApplication {
    name = "hypr-toggle";
    runtimeInputs = [
      pkgs.jq
      pkgs.libnotify
    ];
    text = builtins.readFile ./capture-tools/hypr-toggle.sh;
  };

  dl-media = pkgs.writeShellApplication {
    name = "dl-media";
    runtimeInputs = [
      pkgs.yt-dlp
      pkgs.ffmpeg
      pkgs.wl-clipboard
      pkgs.zenity
      pkgs.libnotify
      pkgs.xdg-utils
    ];
    text = builtins.readFile ./capture-tools/dl-media.sh;
  };
in
{
  home.packages = [
    zoom
    ocr
    recaudio
    webcam
    media-fix
    convert-file
    hypr-toggle
    dl-media
  ];
}
