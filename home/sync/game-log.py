# Game playtime -> Obsidian daily notes ("## Played" plus a gamesPlayed property).
# Steam games come from Steam's own log; others (WoW) from `--watch`.
# Redoes the last two weeks each run, so it's safe to rerun.
import json
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.request
from collections import defaultdict
from datetime import date, datetime, timedelta

VAULT = sys.argv[1]
STEAM = os.path.expanduser("~/.local/share/Steam")
LOGS = [os.path.join(STEAM, "logs", f) for f in ("gameprocess_log.previous.txt", "gameprocess_log.txt")]
STATE_DIR = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
NAMES = os.path.join(STATE_DIR, "game-log-names.json")
WATCHED = os.path.join(STATE_DIR, "game-log-watched.json")  # [[title, start, end], ...] from --watch
OTHER_GAMES = {"Wow.exe": "World of Warcraft"}  # process name -> title, for games outside Steam
DAYS = 14
MIN_SESSION = 120  # seconds; shorter ones are crashed launches
LINE = re.compile(r"^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\] (?:AppID (\d+) (adding PID|no longer tracking PID) (\d+)|Client version)")
MANAGED = re.compile(r"^## Played\n(?:- [^\w\s].*\n?)*", re.M)


def obsidian_synced(min_age=120):
    """Obsidian open here for 2+ minutes, so Sync has pulled notes made on the phone or at work."""
    up, tick = float(open("/proc/uptime").read().split()[0]), os.sysconf("SC_CLK_TCK")
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            args = open(f"/proc/{pid}/cmdline", "rb").read().split(b"\0")
            started = int(open(f"/proc/{pid}/stat").read().rsplit(")", 1)[1].split()[19]) / tick
        except (OSError, IndexError, ValueError):
            continue
        if any(a.endswith(b"/obsidian/app.asar") for a in args) and not any(a.startswith(b"--type=") for a in args):
            if up - started >= min_age:
                return True
    return False


def sessions():
    """(appid, start, end) for every game session in the log."""
    pids, start, last, out = defaultdict(set), {}, {}, []
    for path in LOGS:
        if not os.path.exists(path):
            continue
        for line in open(path, encoding="utf-8", errors="replace"):
            m = LINE.match(line)
            if not m:
                continue
            t = datetime.strptime(m.group(1), "%Y-%m-%d %H:%M:%S")
            if not m.group(2):  # Steam restarted: anything still open ended when last seen
                out += [(a, start.pop(a), last[a]) for a in list(start)]
                pids.clear()
                continue
            app, pid = m.group(2), m.group(4)
            last[app] = t
            if m.group(3) == "adding PID":
                start.setdefault(app, t)
                pids[app].add(pid)
            else:
                pids[app].discard(pid)
                if not pids[app] and app in start:
                    out.append((app, start.pop(app), t))
    for app, t in start.items():  # still playing now
        running = subprocess.run(["pgrep", "-f", f"AppId={app}( |$)"], capture_output=True).returncode == 0
        out.append((app, t, datetime.now() if running else last[app]))
    return [s for s in out if (s[2] - s[1]).total_seconds() >= MIN_SESSION]


def load_watched():
    try:
        return json.load(open(WATCHED))
    except (OSError, ValueError):
        return []


def watched_sessions():
    """(title, start, end) for non-Steam games recorded by --watch."""
    out = [(t, datetime.fromisoformat(s), datetime.fromisoformat(e)) for t, s, e in load_watched()]
    return [s for s in out if (s[2] - s[1]).total_seconds() >= MIN_SESSION]


def watch(every=60):
    """Check once a minute which OTHER_GAMES are running; extend or start their sessions."""
    while True:
        running = set()
        for pid in filter(str.isdigit, os.listdir("/proc")):
            try:
                comm = open(f"/proc/{pid}/comm").read().strip()
            except OSError:
                continue
            if comm in OTHER_GAMES:
                running.add(OTHER_GAMES[comm])
        if running:
            now = datetime.now().replace(microsecond=0)
            cutoff = (now - timedelta(days=DAYS + 1)).isoformat()
            rows = [r for r in load_watched() if r[2] >= cutoff]
            for title in running:
                open_row = next((r for r in reversed(rows) if r[0] == title), None)
                # a gap of 3+ minutes (sleep, PC off) starts a new session
                if open_row and now - datetime.fromisoformat(open_row[2]) < timedelta(minutes=3):
                    open_row[2] = now.isoformat()
                else:
                    rows.append([title, now.isoformat(), now.isoformat()])
            os.makedirs(STATE_DIR, exist_ok=True)
            fd, tmp = tempfile.mkstemp(dir=STATE_DIR, prefix=".game-log-watched-")
            with os.fdopen(fd, "w") as f:
                json.dump(rows, f, indent=0)
            os.replace(tmp, WATCHED)
        time.sleep(every)


def name(app, names):
    if app not in names:
        acf = os.path.join(STEAM, "steamapps", f"appmanifest_{app}.acf")
        m = re.search(r'"name"\s+"([^"]+)"', open(acf).read()) if os.path.exists(acf) else None
        if m:
            names[app] = m.group(1)
        else:  # uninstalled since: ask the Steam store once
            try:
                url = f"https://store.steampowered.com/api/appdetails?appids={app}&filters=basic"
                with urllib.request.urlopen(url, timeout=10) as r:
                    names[app] = json.loads(r.read())[app]["data"]["name"]
            except Exception:
                return f"Steam app {app}"
    return names[app]


def daily_path(d):
    """Today's daily note: an existing YYYY-MM-DD note anywhere in the daily folder, else
    where DAILY_NOTE_FORMAT (Obsidian's daily-notes syntax, from home/sync/daily-note.nix) puts it."""
    folder = os.path.join(VAULT, os.environ["DAILY_NOTE_FOLDER"])
    for root, _, files in os.walk(folder):
        if f"{d:%Y-%m-%d}.md" in files:
            return os.path.join(root, f"{d:%Y-%m-%d}.md")
    tokens = {"YYYY": "%Y", "MMMM": "%B", "MM": "%m", "DD": "%d", "dddd": "%A", "WW": "%V",
              "W": str(d.isocalendar()[1])}
    fmt = re.sub(r"\[([^\]]*)\]|YYYY|MMMM|MM|DD|dddd|WW|W",
                 lambda m: m.group(1).replace("%", "%%") if m.group(1) is not None else tokens[m.group(0)],
                 os.environ["DAILY_NOTE_FORMAT"])
    return os.path.join(folder, d.strftime(fmt) + ".md")


def link(title):
    """[[note|title]] when the game has a Collections/Games note, else just the title."""
    folder = os.path.join(VAULT, "Collections", "Games")
    key = re.sub(r"[^a-z0-9]", "", title.lower())
    for f in os.listdir(folder) if os.path.isdir(folder) else []:
        if f.endswith(".md") and re.sub(r"[^a-z0-9]", "", f[:-3].lower().split("(")[0]) == key:
            return f"[[{f[:-3]}|{title}]]"
    return title


def length(secs):
    h, m = divmod(round(secs / 60), 60)
    return f"{h}h {m:02d}m" if h else f"{m}m"


def put(lines, k, v):
    out, skip, found = [], False, False
    for line in lines:
        if skip and (not line or line[0].isspace() or line.startswith("-")):
            continue
        skip = False
        if line.split(":", 1)[0] == k:
            out.append(f"{k}: {json.dumps(v, ensure_ascii=False)}")
            skip = found = True
        else:
            out.append(line)
    return out if found else out + [f"{k}: {json.dumps(v, ensure_ascii=False)}"]


def update(d, games):
    path = daily_path(d)
    if os.path.exists(path):
        text = open(path, encoding="utf-8").read()
    elif d < date.today():
        text = d.strftime(f"# %A, %B {d.day}\n\n- \n")
    else:
        return False  # today's note comes from Obsidian (maybe the phone's); filled in once it's here
    m = re.match(r"---\n(.*?)\n---\n?", text, re.S)
    fm, body = (m.group(1).split("\n"), text[m.end():]) if m else ([], text)
    ranked = sorted(games.items(), key=lambda g: -g[1])
    fm = put(fm, "gamesPlayed", ", ".join(f"{t} {length(s)}" for t, s in ranked))
    block = "\n".join(["## Played", *(f"- 🎮 {link(t)} · {length(s)}" for t, s in ranked)]) + "\n"
    body = MANAGED.sub(lambda _: block, body, count=1) if MANAGED.search(body) else body.rstrip("\n") + "\n\n" + block
    out = "---\n" + "\n".join(fm) + "\n---\n" + body
    if out == text:
        return False
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(VAULT), prefix=".game-log-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(out)
    os.replace(tmp, path)
    return True


if "--watch" in sys.argv:
    watch()
if not obsidian_synced():
    print("Games: waiting until Obsidian has been open a couple of minutes (so it can't clash with the phone).")
    sys.exit()
names = json.load(open(NAMES)) if os.path.exists(NAMES) else {}
first = date.today() - timedelta(days=DAYS - 1)
days = defaultdict(lambda: defaultdict(float))
for app, start, end in sessions() + watched_sessions():
    title = name(app, names) if app.isdigit() else app
    t = start
    while t < end:  # split sessions that run past midnight
        cut = min(end, datetime.combine(t.date() + timedelta(days=1), datetime.min.time()))
        if t.date() >= first:
            days[t.date()][title] += (cut - t).total_seconds()
        t = cut
changed = 0
for d, games in sorted(days.items()):
    games = {g: s for g, s in games.items() if s >= MIN_SESSION}
    changed += bool(games) and update(d, games)
os.makedirs(STATE_DIR, exist_ok=True)
with open(NAMES, "w") as f:
    json.dump(names, f, indent=0, sort_keys=True)
print(f"Games: {changed} daily notes updated.")
