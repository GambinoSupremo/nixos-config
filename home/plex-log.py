# Plex webhooks -> Obsidian Collections notes. Play creates the note and sets started;
# scrobble (~90% watched) marks a movie watched or bumps a show's lastWatched.
# On start it also catches up on whatever Plex logged while this PC was off. Finished
# episodes and movies also go under "## Watched" in that day's daily note.
import email.parser
import email.policy
import json
import os
import re
import sys
import tempfile
import threading
import time
import urllib.parse
import urllib.request
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VAULT, PORT, PLEX_IP = (sys.argv[1:4] + [None] * 3)[:3]
OWNER_ID = 1  # the server owner's local account id; shared users are ignored
MEDIA_DB = os.path.join(VAULT, ".obsidian/plugins/obsidian-media-db-plugin/data.json")
KEYS = ["title", "year", "image", "watched", "started", "lastWatched", "personalRating"]
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "plex-log-last")
TOKEN_FILE = os.path.expanduser("~/.config/plex-token")  # optional; not needed if Plex allows this PC without auth


def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "plex-log/1.0"}), timeout=10) as r:
        return r.read()


def lookup(title, kind, imdb=None):
    """Title, Year and Poster URL: OMDb first, Cinemeta (no key) when OMDb is down or empty."""
    try:
        key = json.load(open(MEDIA_DB))["OMDbKeyId"]
        q = {"apikey": key, "type": kind, **({"i": imdb} if imdb else {"t": title})}
        d = json.loads(fetch("https://www.omdbapi.com/?" + urllib.parse.urlencode(q)))
        if d.get("Response") == "True" and d.get("Poster", "N/A") != "N/A":
            return d
    except Exception as e:
        print(f"OMDb lookup failed for {title}: {e}", flush=True)
    norm = lambda t: re.sub(r"[^a-z0-9]", "", t.lower().replace("&", "and"))  # noqa: E731
    try:
        base = "https://v3-cinemeta.strem.io"
        if imdb:
            metas = [json.loads(fetch(f"{base}/meta/{kind}/{imdb}.json")).get("meta", {})]
        else:
            url = f"{base}/catalog/{kind}/top/search={urllib.parse.quote(title)}.json"
            metas = json.loads(fetch(url)).get("metas", [])
        m = next((m for m in metas if m.get("poster") and (imdb or norm(m.get("name", "")) == norm(title))), None)
        if m:
            return {"Title": m["name"], "Year": str(m.get("releaseInfo", "")), "Poster": m["poster"]}
    except Exception as e:
        print(f"Cinemeta lookup failed for {title}: {e}", flush=True)
    return {}


def save_poster(url, name):
    """Keep posters in the vault so cards work on the phone away from home."""
    if not url:
        return ""
    try:
        data = fetch(url)
    except Exception as e:
        print(f"Poster download failed for {name}: {e}", flush=True)
        return ""
    fname = re.sub(r'[\\/:*?"<>|#^\[\]]', "", name) + (".webp" if data[8:12] == b"WEBP" else ".jpg")
    folder = os.path.join(VAULT, "Attachments", "Posters")
    os.makedirs(folder, exist_ok=True)
    with open(os.path.join(folder, fname), "wb") as f:
        f.write(data)
    return f"[[{fname}]]"


def read_note(path):
    s = open(path, encoding="utf-8").read()
    m = re.match(r"---\n(.*?)\n---\n?", s, re.S)
    if not m:
        return {}, [], s
    blocks, order, cur = {}, [], None
    for line in m.group(1).split("\n"):
        if line and not line[0].isspace() and not line.startswith("-") and ":" in line:
            cur = line.split(":", 1)[0]
            blocks[cur] = [line]
            order.append(cur)
        elif cur:
            blocks[cur].append(line)
    return blocks, order, s[m.end():]


def value(blocks, k):
    v = blocks.get(k, [""])[0].split(":", 1)[-1].strip()
    return v.strip('"')


def write_note(path, blocks, order, body):
    text = "---\n" + "\n".join(line for k in order for line in blocks[k]) + "\n---\n" + body
    # Temp file outside the vault so Sync never sees a half-written note.
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(VAULT), prefix=".plex-log-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def daily_path(day):
    """Daily note path from Obsidian's own daily-notes setting."""
    cfg = json.load(open(os.path.join(VAULT, ".obsidian", "daily-notes.json")))
    tokens = {"YYYY": "%Y", "MMMM": "%B", "MM": "%m", "DD": "%d", "dddd": "%A"}
    fmt = re.sub("YYYY|MMMM|MM|DD|dddd", lambda m: tokens[m.group(0)], cfg.get("format") or "YYYY-MM-DD")
    return os.path.join(VAULT, cfg.get("folder", ""), day.strftime(fmt) + ".md")


def log_watched(day, entry):
    """Add one line under ## Watched in that day's note (once)."""
    d = date.fromisoformat(day)
    path = daily_path(d)
    text = open(path, encoding="utf-8").read() if os.path.exists(path) else d.strftime(f"# %A, %B {d.day}\n\n- \n")
    if entry in text.split("\n"):
        return
    m = re.search(r"^## Watched\n(?:- [^\w\s].*\n?)*", text, re.M)
    if m:
        section = m.group(0).rstrip("\n") + "\n" + entry + "\n"
        text = text[:m.start()] + section + text[m.end():]
    else:
        text = text.rstrip("\n") + "\n\n## Watched\n" + entry + "\n"
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(VAULT), prefix=".plex-log-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def find_note(folder, title):
    for f in os.listdir(folder):
        if f.endswith(".md"):
            p = os.path.join(folder, f)
            if value(read_note(p)[0], "title").lower() == title.lower():
                return p
    return None


def handle(event, md, today=None):
    today = today or date.today().isoformat()
    info, year = {}, ""
    if md.get("type") == "movie":
        folder, kind, title = "Movies", "movie", md.get("title", "")
        imdb = next((g["id"][7:] for g in md.get("Guid", []) if g.get("id", "").startswith("imdb://")), None)
    elif md.get("type") == "episode":
        folder, kind, title, imdb = "TV", "series", md.get("grandparentTitle", ""), None
    else:
        return
    folder = os.path.join(VAULT, "Collections", folder)
    os.makedirs(folder, exist_ok=True)
    path = find_note(folder, title)
    if path is None:
        info = lookup(title, kind, imdb)
        title = info.get("Title", title)
        year = info.get("Year", str(md.get("year", "")))
        path = find_note(folder, title) or os.path.join(
            folder, re.sub(r'[\\/:*?"<>|#^\[\]]', "", f"{title} ({year})" if year else title) + ".md")
    if os.path.exists(path):
        blocks, order, body = read_note(path)
    else:
        blocks, order, body = {}, [], ""
        new = {"title": title, "year": year, "image": save_poster(info.get("Poster"), os.path.basename(path)[:-3]),
               "watched": False,
               "started": "", "lastWatched": "", "personalRating": 0}
        for k in KEYS:
            blocks[k] = [f"{k}: {json.dumps(new[k], ensure_ascii=False)}"]
            order.append(k)
        print(f"New note: {os.path.basename(path)}", flush=True)

    def put(k, v):
        if k not in blocks:
            order.append(k)
        blocks[k] = [f"{k}: {json.dumps(v, ensure_ascii=False)}"]

    # Lookups can fail; fill in a missing poster on a later event.
    if not value(blocks, "image") and (info := info or lookup(title, kind, imdb)).get("Poster"):
        put("image", save_poster(info["Poster"], os.path.basename(path)[:-3]))
        if not value(blocks, "year"):
            put("year", info.get("Year", ""))
    if event in ("media.play", "media.resume") and not value(blocks, "started"):
        put("started", today)
    if event == "media.scrobble":
        if not value(blocks, "started") or value(blocks, "started") > today:
            put("started", today)
        if value(blocks, "lastWatched") < today:
            put("lastWatched", today)
        if kind == "movie":
            put("watched", True)
    write_note(path, blocks, order, body)
    if event == "media.scrobble":
        note = f"[[{os.path.basename(path)[:-3]}|{value(blocks, 'title') or title}]]"
        if kind == "movie":
            log_watched(today, f"- 🎬 {note}")
        else:
            ep = f"S{md['parentIndex']}E{md['index']}" if md.get("parentIndex") and md.get("index") else ""
            name = f'"{md["title"]}"' if md.get("title") else ""
            log_watched(today, " · ".join(filter(None, [f"- 📺 {note}", " ".join(filter(None, [ep, name]))])))


def save_last(ts):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        f.write(str(int(ts)))


def catch_up():
    """Log views from Plex's history that happened since the last check (e.g. while the PC was off)."""
    if not os.path.exists(STATE):
        return save_last(time.time())  # first run: start from now, the old history was imported once
    last = int(open(STATE).read().strip() or 0)
    headers = {"Accept": "application/json"}
    if os.path.exists(TOKEN_FILE):
        headers["X-Plex-Token"] = open(TOKEN_FILE).read().strip()
    url = f"http://{PLEX_IP}:32400/status/sessions/history/all?sort=viewedAt:asc&viewedAt>={last + 1}&accountID={OWNER_ID}"
    for attempt in range(10):  # the network can take a moment after login
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=30) as r:
                views = json.loads(r.read())["MediaContainer"].get("Metadata", [])
            break
        except Exception as e:
            if attempt == 9:
                print(f"Catch-up couldn't reach Plex: {e}", flush=True)
                return
            time.sleep(30)
    for v in views:
        if v.get("accountID") != OWNER_ID or v.get("viewedAt", 0) <= last:
            continue
        try:
            handle("media.scrobble", v, date.fromtimestamp(v["viewedAt"]).isoformat())
            print(f"Caught up: {v.get('grandparentTitle') or v.get('title')}", flush=True)
        except Exception as e:
            print(f"Couldn't catch up on {v.get('title')}: {e}", flush=True)
        last = max(last, v["viewedAt"])
    save_last(max(last, time.time() - 60))


class Hook(BaseHTTPRequestHandler):
    def do_POST(self):
        if self.client_address[0] != PLEX_IP:
            self.send_response(403)
            self.end_headers()
            return
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(min(n, 20_000_000))
        self.send_response(200)
        self.end_headers()
        msg = email.parser.BytesParser(policy=email.policy.default).parsebytes(
            b"Content-Type: " + self.headers.get("Content-Type", "").encode() + b"\r\n\r\n" + body)
        for part in msg.iter_parts() if msg.is_multipart() else []:
            if part.get_param("name", header="content-disposition") == "payload":
                p = json.loads(part.get_content())
                if p.get("Account", {}).get("id") != OWNER_ID:
                    return
                if p.get("event") == "media.scrobble":
                    save_last(time.time())
                if p.get("event") in ("media.play", "media.resume", "media.scrobble"):
                    try:
                        handle(p["event"], p.get("Metadata", {}))
                    except Exception as e:
                        print(f"Couldn't log {p.get('event')}: {e}", flush=True)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    threading.Thread(target=catch_up, daemon=True).start()
    ThreadingHTTPServer(("0.0.0.0", int(PORT)), Hook).serve_forever()
