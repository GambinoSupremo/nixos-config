# Screen helpers used by the System menu and keys: zoom, OCR, webcam bubble,
# recording audio choice, recording cleanup and file shrink/convert.
{ pkgs, ... }:

let
  pick = ''
    # Newest files first; prints the chosen path.
    pick() {
      local prompt=$1; shift
      local choice
      choice=$(find "$@" -maxdepth 1 -type f -printf '%T@\t%p\n' 2>/dev/null \
        | sort -rn | head -40 | cut -f2- | sed "s|^$HOME/||" \
        | noctalia dmenu -p "$prompt") || exit 0
      [ -n "$choice" ] && echo "$HOME/$choice"
    }
  '';

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
    runtimeInputs = [ pkgs.libnotify ];
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
    text = ''
      ${pick}
      file=$(pick "Recording to fix" "$HOME/Videos/Recordings") || exit 0
      [ -n "$file" ] || exit 0
      what=$(printf 'Trim\nEven out volume\n' | noctalia dmenu -p "''${file##*/}") || exit 0
      case "$what" in
        Trim) exec losslesscut "$file" ;;
        "Even out volume")
          out=''${file%.*}-clean.mp4
          notify-send -a Recorder "Evening out volume" "''${file##*/}"
          ffmpeg -y -loglevel error -i "$file" -c:v copy -af loudnorm=I=-16:TP=-1.5:LRA=11 "$out"
          notify-send -a Recorder "Saved" "''${out##*/}" ;;
      esac
    '';
  };

  convert-file = pkgs.writeShellApplication {
    name = "convert-file";
    runtimeInputs = [
      pkgs.ffmpeg
      pkgs.imagemagick
      pkgs.libnotify
    ];
    text = ''
      ${pick}
      file=$(pick "File to convert" "$HOME/Videos/Recordings" "$HOME/Pictures/Screenshots" "$HOME/Downloads") || exit 0
      [ -n "$file" ] || exit 0
      base=''${file%.*}
      case "''${file,,}" in
        *.mp4 | *.mkv | *.mov | *.webm) opts='Shrink video\nVideo to GIF' ;;
        *.png | *.jpg | *.jpeg | *.webp | *.gif) opts='To WebP\nTo PNG\nTo JPG\nShrink image' ;;
        *) notify-send -a Convert "Can't convert" "''${file##*/}"; exit 0 ;;
      esac
      what=$(printf '%b\n' "$opts" | noctalia dmenu -p "''${file##*/}") || exit 0
      notify-send -a Convert "Working" "$what: ''${file##*/}"
      case "$what" in
        "Shrink video") out=$base-small.mp4
          ffmpeg -y -loglevel error -i "$file" -c:v libx264 -crf 28 -preset slow -c:a aac -b:a 128k "$out" ;;
        "Video to GIF") out=$base.gif
          ffmpeg -y -loglevel error -i "$file" -vf "fps=15,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" "$out" ;;
        "To WebP") out=$base.webp; magick "$file" -quality 85 "$out" ;;
        "To PNG") out=$base.png; magick "$file" "$out" ;;
        "To JPG") out=$base.jpg; magick "$file" -quality 90 "$out" ;;
        "Shrink image") out=$base-small.''${file##*.}; magick "$file" -resize '1920x1920>' -quality 80 "$out" ;;
        *) exit 0 ;;
      esac
      notify-send -a Convert "Saved" "''${out##*/}"
    '';
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
  ];
}
