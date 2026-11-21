# shellcheck shell=bash
# Download video or MP3 audio from a copied link via yt-dlp.

clip=$(wl-paste -n 2>/dev/null || true)
[[ $clip == http://* || $clip == https://* ]] || clip=""
url=$(zenity --entry --title="Download from link" --text="Video or audio link" --entry-text="$clip" --width=480) || exit 0
[ -n "$url" ] || exit 0
kind=$(printf 'Video\nAudio (MP3)\n' | noctalia dmenu -p "Download as") || exit 0
case "$kind" in
  Video)
    dir="$HOME/Videos"
    mkdir -p "$dir"
    notify-send -a Download "Downloading video" "$url"
    out=$(yt-dlp --no-playlist -f "bv*+ba/b" --merge-output-format mp4 -P "$dir" -o "%(title)s.%(ext)s" --print after_move:filepath "$url")
    ;;
  "Audio (MP3)")
    dir="$HOME/Music"
    mkdir -p "$dir"
    notify-send -a Download "Downloading audio" "$url"
    out=$(yt-dlp --no-playlist -x --audio-format mp3 -P "$dir" -o "%(title)s.%(ext)s" --print after_move:filepath "$url")
    ;;
  *) exit 0 ;;
esac
if [ -n "${out:-}" ] && [ -e "$out" ]; then
  case "$(notify-send -a Download --action=open=Open --action=folder="Show folder" "Download saved" "${out##*/}")" in
    open) xdg-open "$out" ;;
    folder) xdg-open "$dir" ;;
  esac
else
  notify-send -a Download "Download failed" "$url"
fi
