# shellcheck shell=bash
# Shrink or convert recent videos, screenshots, and downloads.

pick() {
  local prompt=$1
  shift
  local choice
  choice=$(find "$@" -maxdepth 1 -type f -printf '%T@\t%p\n' 2>/dev/null \
    | sort -rn | head -40 | cut -f2- | sed "s|^$HOME/||" \
    | noctalia dmenu -p "$prompt") || exit 0
  [ -n "$choice" ] && echo "$HOME/$choice"
}

file=$(pick "File to convert" "$HOME/Videos/Recordings" "$HOME/Pictures/Screenshots" "$HOME/Downloads") || exit 0
[ -n "$file" ] || exit 0
base=${file%.*}
case "${file,,}" in
  *.mp4 | *.mkv | *.mov | *.webm) opts='Shrink video\nVideo to GIF' ;;
  *.png | *.jpg | *.jpeg | *.webp | *.gif) opts='To WebP\nTo PNG\nTo JPG\nShrink image' ;;
  *)
    notify-send -a Convert "Can't convert" "${file##*/}"
    exit 0
    ;;
esac
what=$(printf '%b\n' "$opts" | noctalia dmenu -p "${file##*/}") || exit 0
notify-send -a Convert "Working" "$what: ${file##*/}"
case "$what" in
  "Shrink video")
    out=$base-small.mp4
    ffmpeg -y -loglevel error -i "$file" -c:v libx264 -crf 28 -preset slow -c:a aac -b:a 128k "$out"
    ;;
  "Video to GIF")
    out=$base.gif
    ffmpeg -y -loglevel error -i "$file" -vf "fps=15,scale=720:-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse" "$out"
    ;;
  "To WebP")
    out=$base.webp
    magick "$file" -quality 85 "$out"
    ;;
  "To PNG")
    out=$base.png
    magick "$file" "$out"
    ;;
  "To JPG")
    out=$base.jpg
    magick "$file" -quality 90 "$out"
    ;;
  "Shrink image")
    out=$base-small.${file##*.}
    magick "$file" -resize '1920x1920>' -quality 80 "$out"
    ;;
  *) exit 0 ;;
esac
notify-send -a Convert "Saved" "${out##*/}"
