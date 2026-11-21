# shellcheck shell=bash
# Check wallpaper inbox (or a folder) for low-res or portrait images.

root=${1:-$HOME/Pictures/wallpaper-inbox}
[ -d "$root" ] || {
  echo "No folder: $root" >&2
  exit 1
}
bad=0
total=0
while IFS= read -r -d "" f; do
  total=$((total + 1))
  dims=$(identify -format '%w %h' "${f}[0]" 2>/dev/null || true)
  if [ -z "$dims" ]; then
    printf 'BAD   %-14s %s (not a readable image)\n' "?" "${f#"$root"/}"
    bad=$((bad + 1))
    continue
  fi
  read -r w h <<<"$dims"
  if [ "$w" -lt 2560 ]; then
    printf 'SMALL %-14s %s (< 2560 px wide)\n' "${w}x${h}" "${f#"$root"/}"
    bad=$((bad + 1))
  elif [ "$h" -gt "$w" ]; then
    printf 'TALL  %-14s %s (portrait)\n' "${w}x${h}" "${f#"$root"/}"
    bad=$((bad + 1))
  else
    printf 'OK    %-14s %s\n' "${w}x${h}" "${f#"$root"/}"
  fi
done < <(find "$root" -type f -print0 | sort -z)
echo "Checked $total image(s); $bad flagged."
