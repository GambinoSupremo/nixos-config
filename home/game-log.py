# Steam playtime -> Obsidian daily notes ("## Played" plus a gamesPlayed property), worked out
# from Steam's own game process log. Recomputes the last week each run, so it's safe to rerun.
import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.request
from collections import defaultdict
from datetime import date, datetime, timedelta

VAULT = sys.argv[1]
STEAM = os.path.expanduser("~/.local/share/Steam")
LOGS = [os.path.join(STEAM, "logs", f) for f in ("gameprocess_log.previous.txt", "gameprocess_log.txt")]
STATE_DIR = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
NAMES = os.path.join(STATE_DIR, "game-log-names.json")
DAYS = 7
MIN_SESSION = 120  # seconds; shorter ones are crashed launches
LINE = re.compile(r"^\[(\d{4}-\d\d-\d\d \d\d:\d\d:\d\d)\] (?:AppID (\d+) (adding PID|no longer tracking PID) (\d+)|Client version)")
MANAGED = re.compile(r"^## Played\n(?:- [^\w\s].*\n?)*", re.M)


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
    """Daily note path from Obsidian's own daily-notes setting."""
    cfg = json.load(open(os.path.join(VAULT, ".obsidian", "daily-notes.json")))
    tokens = {"YYYY": "%Y", "MMMM": "%B", "MM": "%m", "DD": "%d", "dddd": "%A"}
    fmt = re.sub("YYYY|MMMM|MM|DD|dddd", lambda m: tokens[m.group(0)], cfg.get("format") or "YYYY-MM-DD")
    return os.path.join(VAULT, cfg.get("folder", ""), d.strftime(fmt) + ".md")


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
    else:
        text = d.strftime(f"# %A, %B {d.day}\n\n- \n")
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


names = json.load(open(NAMES)) if os.path.exists(NAMES) else {}
first = date.today() - timedelta(days=DAYS - 1)
days = defaultdict(lambda: defaultdict(float))
for app, start, end in sessions():
    t = start
    while t < end:  # split sessions that run past midnight
        cut = min(end, datetime.combine(t.date() + timedelta(days=1), datetime.min.time()))
        if t.date() >= first:
            days[t.date()][name(app, names)] += (cut - t).total_seconds()
        t = cut
changed = 0
for d, games in sorted(days.items()):
    games = {g: s for g, s in games.items() if s >= MIN_SESSION}
    changed += bool(games) and update(d, games)
os.makedirs(STATE_DIR, exist_ok=True)
with open(NAMES, "w") as f:
    json.dump(names, f, indent=0, sort_keys=True)
print(f"Games: {changed} daily notes updated.")
