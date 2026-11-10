# Todoist check-offs -> Obsidian daily notes ("## Done" plus a tasksDone count), recurring
# ones included. Todoist Free only shows a week of activity, so events are kept locally.
import getpass
import json
import os
import re
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import date, datetime, timedelta

VAULT = sys.argv[1]
MODE = sys.argv[2] if len(sys.argv) > 2 else "sync"
API = "https://api.todoist.com/api/v1"
DATA = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
STATE_DIR = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
TOKEN = os.path.join(DATA, "todoist-log", "token")
STORE = os.path.join(STATE_DIR, "todoist-log.json")
DAYS = 14  # notes rewritten each run
KEEP = 30  # days of events kept locally
MANAGED = re.compile(r"^## Done\n(?:- [^\w\s].*\n?)*", re.M)


def login():
    print("Todoist → Settings → Integrations → Developer → copy the API token.")
    token = getpass.getpass("Todoist API token: ").strip()
    get("/user", token=token)  # fails loudly if the token is wrong
    os.makedirs(os.path.dirname(TOKEN), exist_ok=True)
    fd = os.open(TOKEN, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(token)
    print("Saved. todoist-log will now run on its own every half hour.")


def get(path, token=None, **params):
    url = API + path + ("?" + urllib.parse.urlencode(params) if params else "")
    req = urllib.request.Request(url, headers={"Authorization": f"Bearer {token or TOKEN_VALUE}",
                                               "User-Agent": "todoist-log"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def pages(path, **params):
    cursor = None
    while True:
        data = get(path, **params, **({"cursor": cursor} if cursor else {}))
        yield from data.get("results", [])
        cursor = data.get("next_cursor")
        if not cursor:
            return


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


def daily_path(d):
    """An existing YYYY-MM-DD note anywhere in the daily folder, else where
    DAILY_NOTE_FORMAT (Obsidian's daily-notes syntax, from home/daily-note.nix) puts it."""
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


def fetch(store):
    """Add this week's completed/uncompleted task events to the local store."""
    if not store.get("me"):
        store["me"] = str(get("/user")["id"])
    store["projects"] = {str(p["id"]): ("" if p.get("inbox_project") else p["name"]) for p in pages("/projects")}
    for back in (5, 2):  # Free plan refuses dates past its history limit; runs every 30 min anyway
        try:
            events = list(pages("/activities", object_event_types='["item:completed","item:uncompleted"]',
                                date_from=(date.today() - timedelta(days=back)).isoformat(), limit=100))
            break
        except urllib.error.HTTPError as e:
            if e.code != 403 or back == 2:
                raise
    for e in events:
        if str(e.get("initiator_id") or store["me"]) != store["me"]:
            continue  # a collaborator's check-off
        when = datetime.fromisoformat(e["event_date"].replace("Z", "+00:00")).astimezone()
        store["events"][str(e["id"])] = {
            "type": e["event_type"], "task": str(e["object_id"]), "when": when.isoformat(),
            "content": " ".join((e.get("extra_data") or {}).get("content", "").split()),
            "project": str(e.get("parent_project_id") or "")}


def done_by_day(store):
    """Completions per local day, minus any that were unchecked afterwards."""
    done = {}
    for ev in sorted(store["events"].values(), key=lambda v: v["when"]):
        if ev["type"] == "completed":
            done.setdefault(ev["task"], []).append(ev)
        elif ev["type"] == "uncompleted" and done.get(ev["task"]):
            done[ev["task"]].pop()
    days = {date.fromisoformat(e["when"][:10]): [] for e in store["events"].values()}  # so undone days clear
    for ev in sorted((e for evs in done.values() for e in evs), key=lambda v: v["when"]):
        days.setdefault(date.fromisoformat(ev["when"][:10]), []).append(ev)
    return days


def update(d, evs, projects):
    path = daily_path(d)
    if os.path.exists(path):
        text = open(path, encoding="utf-8").read()
    elif d < date.today() and evs:
        text = d.strftime(f"# %A, %B {d.day}\n\n- \n")
    else:
        return False  # today's note comes from Obsidian (maybe the phone's); filled in once it's here
    m = re.match(r"---\n(.*?)\n---\n?", text, re.S)
    fm, body = (m.group(1).split("\n"), text[m.end():]) if m else ([], text)
    lines = []
    for ev in evs:
        project = projects.get(ev["project"], "")
        lines.append(f"- ✅ {ev['content']}" + (f" · {project}" if project else ""))
    block = "\n".join(["## Done", *lines]) + "\n" if lines else ""
    found = list(MANAGED.finditer(body))
    for m in reversed(found[1:]):  # a doubled-up section
        body = body[:m.start()].rstrip("\n") + "\n" + body[m.end():].lstrip("\n")
    if found:
        body = MANAGED.sub(lambda _: block, body, count=1)
    elif block:
        body = body.rstrip("\n") + "\n\n" + block
    else:
        return False
    fm = put(fm, "tasksDone", len(lines)) if lines else [l for l in fm if l.split(":", 1)[0] != "tasksDone"]
    out = ("---\n" + "\n".join(fm) + "\n---\n" if fm else "") + body
    if out == text:
        return False
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(VAULT), prefix=".todoist-log-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(out)
    os.replace(tmp, path)
    return True


if MODE == "login":
    login()
    sys.exit()
if not os.path.exists(TOKEN):
    print("Not logged in to Todoist yet. Run: todoist-log login")
    sys.exit(0 if MODE == "auto" else 1)
TOKEN_VALUE = open(TOKEN).read().strip()
try:
    store = json.load(open(STORE))
except (OSError, ValueError):
    store = {"events": {}}
try:
    fetch(store)
except urllib.error.HTTPError as e:
    print(f"Todoist said {e.code} ({e.read()[:200]!r}). If the token changed, run: todoist-log login")
    sys.exit(0 if MODE == "auto" and e.code != 401 else 1)
cutoff = (datetime.now() - timedelta(days=KEEP)).astimezone().isoformat()
store["events"] = {k: v for k, v in store["events"].items() if v["when"] >= cutoff}
os.makedirs(STATE_DIR, exist_ok=True)
with open(STORE + ".tmp", "w") as f:
    json.dump(store, f, indent=0)
os.replace(STORE + ".tmp", STORE)

if not obsidian_synced():
    print("Todoist: saved; waiting until Obsidian has been open a couple of minutes to write notes.")
    sys.exit()
days = done_by_day(store)
first = date.today() - timedelta(days=DAYS - 1)
changed = sum(update(d, evs, store["projects"]) for d, evs in sorted(days.items()) if d >= first)
print(f"Todoist: {changed} daily notes updated.")
