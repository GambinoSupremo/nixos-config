# shellcheck shell=bash
# Trim a recording in LosslessCut or normalize its audio volume.

pick() {
  local prompt=$1
  shift
  local choice
  choice=$(find "$@" -maxdepth 1 -type f -printf '%T@\t%p\n' 2>/dev/null \
    | sort -rn | head -40 | cut -f2- | sed "s|^$HOME/||" \
    | noctalia dmenu -p "$prompt") || exit 0
  [ -n "$choice" ] && echo "$HOME/$choice"
}

file=$(pick "Recording to fix" "$HOME/Videos/Recordings") || exit 0
[ -n "$file" ] || exit 0
what=$(printf 'Trim\nEven out volume\n' | noctalia dmenu -p "${file##*/}") || exit 0
case "$what" in
  Trim) exec losslesscut "$file" ;;
  "Even out volume")
    out=${file%.*}-clean.mp4
    notify-send -a Recorder "Evening out volume" "${file##*/}"
    ffmpeg -y -loglevel error -i "$file" -c:v copy -af loudnorm=I=-16:TP=-1.5:LRA=11 "$out"
    notify-send -a Recorder "Saved" "${out##*/}"
    ;;
esac
