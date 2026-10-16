# Garmin Connect -> Obsidian daily notes: steps, sleep, resting HR and Body Battery as
# properties, plus a Workouts list. Garmin keeps the history, so missed days fill in later.
import getpass
import json
import os
import re
import sys
import tempfile
from datetime import date, timedelta

from garminconnect import Garmin, GarminConnectAuthenticationError

VAULT = sys.argv[1]
MODE = sys.argv[2] if len(sys.argv) > 2 else "sync"
DATA = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
STATE_DIR = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
TOKENS = os.path.join(DATA, "garmin-sync", "tokens.json")
LAST = os.path.join(STATE_DIR, "garmin-sync-last")
MILES = 1609.344
# Garmin type keys (road_biking, trail_running, lap_swimming...) matched by a piece of the name.
ICONS = {"run": "🏃", "bik": "🚴", "cycl": "🚴", "walk": "🚶", "hik": "🥾", "swim": "🏊",
         "strength": "🏋️", "yoga": "🧘"}
# The Workouts heading plus the icon lines under it belong to garmin-sync; anything else you
# write there stays. (Older notes used %% garmin-sync %% markers; those get swapped out.)
OLD_BLOCK = re.compile(r"\n*%% garmin-sync %%.*?%% end garmin-sync %%\n?", re.S)
WORKOUTS = re.compile(r"^## Workouts\n(?:- [^\w\s].*\n?)*", re.M)


def login():
    email = input("Garmin email: ").strip()
    password = getpass.getpass("Garmin password: ")
    api = Garmin(email, password, prompt_mfa=lambda: input("Code Garmin sent you: ").strip())
    api.login(TOKENS)
    print("Logged in. garmin-sync will now run on its own every few hours.")


def daily_path(d):
    """Daily note path from Obsidian's own daily-notes setting (YYYY/MM MMMM/YYYY-MM-DD)."""
    cfg = json.load(open(os.path.join(VAULT, ".obsidian", "daily-notes.json")))
    tokens = {"YYYY": "%Y", "MMMM": "%B", "MM": "%m", "DD": "%d", "dddd": "%A"}
    fmt = re.sub("YYYY|MMMM|MM|DD|dddd", lambda m: tokens[m.group(0)], cfg.get("format") or "YYYY-MM-DD")
    return os.path.join(VAULT, cfg.get("folder", ""), d.strftime(fmt) + ".md")


def split(text):
    m = re.match(r"---\n(.*?)\n---\n?", text, re.S)
    return (m.group(1).split("\n") if m else []), (text[m.end():] if m else text)


def put(lines, k, v):
    """Set one frontmatter property, keeping everything else as it was."""
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


def clock(s):
    s = int(s or 0)
    return f"{s // 3600}:{s % 3600 // 60:02d}:{s % 60:02d}" if s >= 3600 else f"{s // 60}:{s % 60:02d}"


def workout(a, short=False):
    kind = a.get("activityType", {}).get("typeKey", "")
    icon = next((i for k, i in ICONS.items() if k in kind), "💪")
    parts = [f"{icon} {a.get('activityName') or kind.replace('_', ' ').title()}"]
    dist, secs = a.get("distance") or 0, a.get("duration") or 0
    if short:  # for the Fitness board: "🏃 5.20 mi"
        return f"{icon} {dist / MILES:.2f} mi" if dist > 100 else f"{icon} {clock(secs)}"
    if dist > 100:
        parts.append(f"{dist / MILES:.2f} mi")
    parts.append(clock(secs))
    if dist > 100 and secs and icon == "🚴":
        parts.append(f"{dist / MILES / secs * 3600:.1f} mph")
    elif dist > 100 and secs:
        parts.append(f"{clock(secs / (dist / MILES))}/mi")
    if a.get("averageHR"):
        parts.append(f"avg HR {round(a['averageHR'])}")
    return "- " + " · ".join(parts)


def update(d, summary, sleep, acts):
    path = daily_path(d)
    if os.path.exists(path):
        text = open(path, encoding="utf-8").read()
    elif d < date.today():  # today's note is left for Obsidian to make from the template
        text = d.strftime(f"# %A, %B {d.day}\n\n- \n")
    else:
        return False
    fm, body = split(text)
    new = fm
    if summary.get("totalSteps"):
        new = put(new, "steps", summary["totalSteps"])
    secs = (sleep.get("dailySleepDTO") or {}).get("sleepTimeSeconds")
    if secs:
        new = put(new, "sleep", f"{secs // 3600}h {secs % 3600 // 60:02d}m")
    if summary.get("restingHeartRate"):
        new = put(new, "restingHR", summary["restingHeartRate"])
    if summary.get("bodyBatteryHighestValue"):
        new = put(new, "bodyBattery", summary["bodyBatteryHighestValue"])
    if acts:
        new = put(new, "workouts", ", ".join(workout(a, short=True) for a in acts))
    block = "\n".join(["## Workouts", *map(workout, acts)]) + "\n" if acts else ""
    body = OLD_BLOCK.sub("\n", body)
    found = list(WORKOUTS.finditer(body))
    for m in reversed(found[1:]):  # a doubled-up section from an older run
        body = body[:m.start()].rstrip("\n") + "\n" + body[m.end():].lstrip("\n")
    if found:
        body = WORKOUTS.sub(lambda _: block, body, count=1)
    elif block:
        body = body.rstrip("\n") + "\n\n" + block
    out = ("---\n" + "\n".join(new) + "\n---\n" if new else "") + body
    if out == text:
        return False
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(VAULT), prefix=".garmin-sync-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(out)
    os.replace(tmp, path)
    return True


def sync(api):
    today = date.today()
    try:
        start = date.fromisoformat(open(LAST).read().strip()) - timedelta(days=1)
    except (OSError, ValueError):
        start = today - timedelta(days=7)  # first run: the last week
    start = max(start, today - timedelta(days=60))
    acts = {}
    for a in api.get_activities_by_date(start.isoformat(), today.isoformat()):
        acts.setdefault(a.get("startTimeLocal", "")[:10], []).append(a)
    changed, d = 0, start
    while d <= today:
        day = acts.get(d.isoformat(), [])
        day.sort(key=lambda a: a.get("startTimeLocal", ""))
        if update(d, api.get_user_summary(d.isoformat()) or {}, api.get_sleep_data(d.isoformat()) or {}, day):
            changed += 1
        d += timedelta(days=1)
    os.makedirs(STATE_DIR, exist_ok=True)
    with open(LAST, "w") as f:
        f.write(today.isoformat())
    print(f"Garmin: {changed} daily notes updated ({start} to {today}).")


if MODE == "login":
    login()
    sys.exit()
if not os.path.exists(TOKENS):
    print("Not logged in to Garmin yet. Run: garmin-sync login")
    sys.exit(0 if MODE == "auto" else 1)
api = Garmin()
try:
    api.login(TOKENS)
except GarminConnectAuthenticationError as e:
    print(f"Garmin login expired ({e}). Run: garmin-sync login")
    sys.exit(0 if MODE == "auto" else 1)
sync(api)
