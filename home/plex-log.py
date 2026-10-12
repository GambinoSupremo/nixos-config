# Plex webhooks -> Obsidian Collections notes. Play creates the note and sets started;
# scrobble (~90% watched) marks a movie watched or bumps a show's lastWatched.
import email.parser
import email.policy
import json
import os
import re
import sys
import tempfile
import urllib.parse
import urllib.request
from datetime import date
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

VAULT, PORT, PLEX_IP = (sys.argv[1:4] + [None] * 3)[:3]
OWNER_ID = 1  # the server owner's local account id; shared users are ignored
MEDIA_DB = os.path.join(VAULT, ".obsidian/plugins/obsidian-media-db-plugin/data.json")
KEYS = ["title", "year", "image", "watched", "started", "lastWatched", "personalRating"]


def omdb(title, kind, imdb=None):
    try:
        key = json.load(open(MEDIA_DB))["OMDbKeyId"]
        q = {"apikey": key, "type": kind, **({"i": imdb} if imdb else {"t": title})}
        with urllib.request.urlopen("https://www.omdbapi.com/?" + urllib.parse.urlencode(q), timeout=10) as r:
            d = json.load(r)
        if d.get("Poster") == "N/A":
            d.pop("Poster")
        return d if d.get("Response") == "True" else {}
    except Exception as e:
        print(f"OMDb lookup failed for {title}: {e}", flush=True)
        return {}


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


def find_note(folder, title):
    for f in os.listdir(folder):
        if f.endswith(".md"):
            p = os.path.join(folder, f)
            if value(read_note(p)[0], "title").lower() == title.lower():
                return p
    return None


def handle(event, md):
    today = date.today().isoformat()
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
        info = omdb(title, kind, imdb)
        title = info.get("Title", title)
        year = info.get("Year", str(md.get("year", "")))
        path = find_note(folder, title) or os.path.join(
            folder, re.sub(r'[\\/:*?"<>|#^\[\]]', "", f"{title} ({year})" if year else title) + ".md")
    if os.path.exists(path):
        blocks, order, body = read_note(path)
    else:
        blocks, order, body = {}, [], ""
        new = {"title": title, "year": year, "image": info.get("Poster", ""), "watched": False,
               "started": "", "lastWatched": "", "personalRating": 0}
        for k in KEYS:
            blocks[k] = [f"{k}: {json.dumps(new[k], ensure_ascii=False)}"]
            order.append(k)
        print(f"New note: {os.path.basename(path)}", flush=True)

    def put(k, v):
        if k not in blocks:
            order.append(k)
        blocks[k] = [f"{k}: {json.dumps(v, ensure_ascii=False)}"]

    # OMDb is flaky; fill in a missing poster on a later event.
    if not value(blocks, "image") and (info := info or omdb(title, kind, imdb)).get("Poster"):
        put("image", info["Poster"])
        if not value(blocks, "year"):
            put("year", info.get("Year", ""))
    if event in ("media.play", "media.resume") and not value(blocks, "started"):
        put("started", today)
    if event == "media.scrobble":
        if not value(blocks, "started"):
            put("started", today)
        put("lastWatched", today)
        if kind == "movie":
            put("watched", True)
    write_note(path, blocks, order, body)


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
                if p.get("event") in ("media.play", "media.resume", "media.scrobble"):
                    try:
                        handle(p["event"], p.get("Metadata", {}))
                    except Exception as e:
                        print(f"Couldn't log {p.get('event')}: {e}", flush=True)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", int(PORT)), Hook).serve_forever()
