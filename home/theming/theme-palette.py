# Turns a downloaded theme folder (colors.toml, or alacritty.toml) into a
# Noctalia palette on stdout. Prints nothing and exits 1 if no colors found.
import json, sys, tomllib
from pathlib import Path

src = Path(sys.argv[1])
NAMES = ["black", "red", "green", "yellow", "blue", "magenta", "cyan", "white"]


def load(name):
    p = src / name
    try:
        return tomllib.loads(p.read_text()) if p.is_file() else {}
    except (tomllib.TOMLDecodeError, UnicodeDecodeError):
        return {}


def norm(c):
    c = str(c or "").strip().replace("0x", "#")
    return c.lower() if c.startswith("#") and len(c) == 7 else None


c = load("colors.toml")
if norm(c.get("background")):
    ansi = [norm(c.get(f"color{i}")) for i in range(16)]
    bg, fg = norm(c["background"]), norm(c.get("foreground"))
    accent = norm(c.get("accent"))
    sel_fg, sel_bg = norm(c.get("selection_foreground")), norm(c.get("selection_background"))
    cursor = norm(c.get("cursor"))
else:
    a = load("alacritty.toml").get("colors") or {}
    prim, nrm, brt = a.get("primary") or {}, a.get("normal") or {}, a.get("bright") or {}
    bg, fg = norm(prim.get("background")), norm(prim.get("foreground"))
    if not bg:
        sys.exit(1)
    ansi = [norm(nrm.get(n)) for n in NAMES] + [norm(brt.get(n)) for n in NAMES]
    sel = a.get("selection") or {}
    sel_fg, sel_bg = norm(sel.get("text")), norm(sel.get("background"))
    cursor = norm((a.get("cursor") or {}).get("cursor"))
    accent = None

fg = fg or "#cccccc"
ansi = [x or ansi[i - 8] or fg if i >= 8 else x or fg for i, x in enumerate(ansi)]
accent = accent or ansi[4]


def mix(a, b, t):
    pa = [int(a[i : i + 2], 16) for i in (1, 3, 5)]
    pb = [int(b[i : i + 2], 16) for i in (1, 3, 5)]
    return "#" + "".join(f"{round(x + (y - x) * t):02x}" for x, y in zip(pa, pb))


side = {
    "primary": accent,
    "on_primary": bg,
    "secondary": ansi[4],
    "on_secondary": bg,
    "tertiary": ansi[5],
    "on_tertiary": bg,
    "error": ansi[1],
    "on_error": bg,
    "surface": bg,
    "on_surface": fg,
    "surface_container": mix(bg, fg, 0.06),
    "on_surface_variant": ansi[7],
    "outline_variant": ansi[8],
    "shadow": mix(bg, "#000000", 0.5),
    "hover": accent,
    "on_hover": bg,
    "terminal": {
        "normal": dict(zip(NAMES, ansi[:8])),
        "bright": dict(zip(NAMES, ansi[8:16])),
        "foreground": fg,
        "background": bg,
        "selection_fg": sel_fg or fg,
        "selection_bg": sel_bg or mix(bg, accent, 0.3),
        "cursor_text": bg,
        "cursor": cursor or fg,
    },
}
json.dump({"version": 2, "dark": side, "light": side}, sys.stdout, indent=2)
