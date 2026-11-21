# shellcheck shell=bash
# `theme install <github link>`: extract a palette + wallpapers, then switch to it.
# Input from runtimeEnv: THEME_PALETTE_PY.

say() { notify-send -a Theme "$@"; }

url=${1:-}
if [ -z "$url" ]; then
  clip=$(wl-paste -n 2>/dev/null || true)
  [[ $clip == https://github.com/* ]] || clip=""
  url=$(zenity --entry --title="Add theme" --text="GitHub link of the theme" --entry-text="$clip" --width=480) || exit 0
fi
url=${url%/}
url=${url%.git}
if ! [[ $url =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  say "Needs a GitHub link" "e.g. https://github.com/someone/some-theme"
  exit 1
fi

guess=$(sed -E 's/[-_]theme$//I; s/[-_]+/ /g; s/\b(.)/\u\1/g' <<<"${url##*/}")
name=${2:-$(zenity --entry --title="Add theme" --text="Name" --entry-text="$guess")} || exit 0
name=$(tr -d '|' <<<"$name")
[ -n "$name" ] || exit 0
slug=$(tr '[:upper:] ' '[:lower:]-' <<<"$name" | tr -cd 'a-z0-9-')
pal=$(tr ' ' '-' <<<"$name" | tr -cd 'A-Za-z0-9-')
sdir="${XDG_STATE_HOME:-$HOME/.local/state}"
added="$sdir/theme-added"
if theme list | cut -f1 | grep -qxF "$name" && ! grep -q "^$name|" "$added" 2>/dev/null; then
  say "$name already exists" "Pick another name."
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git clone -q --depth 1 "$url" "$work/src" || {
  say "Couldn't download" "$url"
  exit 1
}
python3 -I "$THEME_PALETTE_PY" "$work/src" >"$work/palette.json" || {
  say "No colors found" "$url has no colors.toml or alacritty.toml"
  exit 1
}
mkdir -p "$HOME/.config/noctalia/palettes"
cp "$work/palette.json" "$HOME/.config/noctalia/palettes/$pal.json"
mode=dark
[ -e "$work/src/light.mode" ] && mode=light

walls="$HOME/Pictures/theme-added/$slug"
rm -rf "$walls"
mkdir -p "$walls"
[ -d "$work/src/backgrounds" ] && find "$work/src/backgrounds" -maxdepth 1 -type f \
  \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -exec cp -t "$walls" {} +

tdir="${XDG_CACHE_HOME:-$HOME/.cache}/theme-thumbs"
mkdir -p "$tdir"
img=$(find "$walls" -type f | sort | head -1)
[ -n "$img" ] && magick "$img" -resize 128x128^ -gravity center -extent 128x128 \
  \( -size 128x128 xc:none -fill white -draw 'roundrectangle 0,0 127,127 26,26' \) \
  -compose DstIn -composite "$tdir/$slug.png"

mkdir -p "$sdir"
{
  grep -v "^$name|" "$added" 2>/dev/null || true
  echo "$name|$mode|custom|$pal|theme-added/$slug"
} >"$added.new"
mv "$added.new" "$added"
theme "$name"
say "$name added" "In the Style menu with your other themes."
