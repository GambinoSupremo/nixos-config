# Kobo reading log -> Obsidian Collections/Books notes, for books you've opened. Reads a copy
# of KoboReader.sqlite; covers come from the Kobo itself (Open Library as a fallback).
import json
import os
import re
import shutil
import sqlite3
import sys
import tempfile
import urllib.parse
import urllib.request

KOBO, VAULT = sys.argv[1], sys.argv[2]
BOOKS = os.path.join(VAULT, "Collections", "Books")
POSTERS = os.path.join(VAULT, "Attachments", "Posters")
# Books already imported; a note you delete stays deleted instead of coming back.
SEEN = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "kobo-sync-seen.json")
KEYS = ["title", "author", "coverUrl", "read", "started", "finished", "personalRating"]
norm = lambda t: re.sub(r"[^a-z0-9]", "", t.lower().split(":")[0].replace("&", "and"))  # noqa: E731


def fetch(url):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "kobo-sync/1.0"}), timeout=20) as r:
        return r.read()


def kobo_covers():
    """ImageId -> largest cover file the Kobo has cached for it."""
    best = {}
    for root, _, files in os.walk(os.path.join(KOBO, ".kobo-images")):
        for f in files:
            p = os.path.join(root, f)
            iid = f.split(" - ")[0]
            if iid not in best or os.path.getsize(p) > os.path.getsize(best[iid]):
                best[iid] = p
    return best


def cover(title, author, name, image_id):
    fname = re.sub(r'[\\/:*?"<>|#^\[\]]', "", name) + ".jpg"
    os.makedirs(POSTERS, exist_ok=True)
    if image_id in COVERS:
        shutil.copy(COVERS[image_id], os.path.join(POSTERS, fname))
        return f"[[{fname}]]"
    try:
        q = urllib.parse.urlencode({"title": title.split(":")[0], "author": author.split(",")[0],
                                    "limit": 1, "fields": "cover_i"})
        docs = json.loads(fetch("https://openlibrary.org/search.json?" + q)).get("docs", [])
        if not docs or not docs[0].get("cover_i"):
            return ""
        data = fetch(f"https://covers.openlibrary.org/b/id/{docs[0]['cover_i']}-L.jpg")
    except Exception as e:
        print(f"  (no cover for {title}: {e})")
        return ""
    with open(os.path.join(POSTERS, fname), "wb") as f:
        f.write(data)
    return f"[[{fname}]]"


def read_note(path):
    s = open(path, encoding="utf-8").read()
    m = re.match(r"---\n(.*?)\n---\n?", s, re.S)
    blocks, order, cur = {}, [], None
    for line in (m.group(1).split("\n") if m else []):
        if line and not line[0].isspace() and not line.startswith("-") and ":" in line:
            cur = line.split(":", 1)[0]
            blocks[cur], order = [line], order + [cur]
        elif cur:
            blocks[cur].append(line)
    return blocks, order, s[m.end():] if m else s


def value(blocks, k):
    return blocks.get(k, [""])[0].split(":", 1)[-1].strip().strip('"')


def put(blocks, order, k, v):
    if k not in blocks:
        order.append(k)
    blocks[k] = [f"{k}: {json.dumps(v, ensure_ascii=False)}"]


def write_note(path, blocks, order, body):
    text = "---\n" + "\n".join(line for k in order for line in blocks[k]) + "\n---\n" + body
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(VAULT), prefix=".kobo-sync-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


# Work from a copy so the Kobo's database is never opened for writing.
with tempfile.TemporaryDirectory() as tmpdir:
    db_path = os.path.join(tmpdir, "KoboReader.sqlite")
    shutil.copy(os.path.join(KOBO, ".kobo", "KoboReader.sqlite"), db_path)
    db = sqlite3.connect(f"file:{db_path}?mode=ro", uri=True)
    # Opened books only; downloaded-but-unopened ones are Kobo Plus/wishlist browsing.
    rows = db.execute("""SELECT Title, Attribution, ReadStatus, DateLastRead, LastTimeStartedReading,
                                LastTimeFinishedReading, ImageId
                         FROM content WHERE ContentType = 6
                           AND (ReadStatus > 0 OR IFNULL(DateLastRead, '') != ''
                                OR IFNULL(LastTimeStartedReading, '') != '')""").fetchall()
    db.close()

# One entry per title: the furthest status and the earliest start wins.
books = {}
COVERS = kobo_covers()
for title, author, status, last, started, finished, image_id in rows:
    b = books.setdefault(norm(title), {"title": title, "author": author or "", "status": 0,
                                       "started": "", "finished": "", "image": image_id})
    day = lambda t: (t or "")[:10]  # noqa: E731
    if status == 2 and status >= b["status"]:
        b["finished"] = max(b["finished"], day(finished) or day(last))
    b["status"] = max(b["status"], status or 0)
    if day(started) and (not b["started"] or day(started) < b["started"]):
        b["started"] = day(started)

os.makedirs(BOOKS, exist_ok=True)
existing = {}
for f in os.listdir(BOOKS):
    if f.endswith(".md"):
        existing[norm(value(read_note(os.path.join(BOOKS, f))[0], "title") or f[:-3])] = os.path.join(BOOKS, f)

seen = set(json.load(open(SEEN))) if os.path.exists(SEEN) else set()
created = updated = 0
for key, b in sorted(books.items()):
    path = existing.get(key)
    if not path and key in seen:
        continue
    seen.add(key)
    if path:
        blocks, order, body = read_note(path)
    else:
        name = f"{b['title'].split(':')[0]} - {b['author'].split(',')[0]}".strip(" -")
        path = os.path.join(BOOKS, re.sub(r'[\\/:*?"<>|#^\[\]]', "", name) + ".md")
        new = {"title": b["title"], "author": b["author"].replace(",", ", "),
               "coverUrl": cover(b["title"], b["author"], name, b["image"]), "read": False,
               "started": "", "finished": "", "personalRating": 0}
        blocks = {k: [f"{k}: {json.dumps(new[k], ensure_ascii=False)}"] for k in KEYS}
        order, body = list(KEYS), ""
        created += 1
        print(f"  new: {b['title']}")
    before = dict(blocks)

    if not value(blocks, "coverUrl"):
        put(blocks, order, "coverUrl", cover(b["title"], b["author"], os.path.basename(path)[:-3], b["image"]) or "")
    if b["started"] and not value(blocks, "started"):
        put(blocks, order, "started", b["started"])
    if b["status"] == 2:
        if value(blocks, "read") != "true":
            put(blocks, order, "read", True)
        if b["finished"] and not value(blocks, "finished"):
            put(blocks, order, "finished", b["finished"])
    if path in existing.values():
        if blocks == before:
            continue
        updated += 1
        print(f"  updated: {b['title']}")
    write_note(path, blocks, order, body)

os.makedirs(os.path.dirname(SEEN), exist_ok=True)
with open(SEEN, "w") as f:
    json.dump(sorted(seen), f)
print(f"Kobo: {len(books)} books, {created} new notes, {updated} updated.")
