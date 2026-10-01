{ pkgs, ... }:

let
  # Noctalia post_hook: push the regenerated palette into the running Tidal page via
  # its localhost DevTools port (Tidal only reads theme files at load).
  tidalLiveTheme = pkgs.writers.writePython3Bin "tidal-live-theme" {
    libraries = [ pkgs.python3Packages.websocket-client ];
  } ''
    import json
    import os
    import re
    import urllib.request
    import websocket

    theme = "~/.config/tidal-hifi/themes/noctalia.css"
    css = open(os.path.expanduser(theme)).read()
    m = re.search(r"html:root\s*\{([^}]*)\}", css)
    if not m:
        raise SystemExit("palette block not found")
    # Triple :root outranks the html:root block injected at launch.
    rule = ":root:root:root {" + m.group(1) + "}"
    try:
        url = "http://127.0.0.1:9233/json/list"
        targets = json.load(urllib.request.urlopen(url, timeout=2))
    except OSError:
        raise SystemExit(0)  # Tidal not running
    js = (
        "(()=>{let s=document.getElementById('noctalia-live');"
        "if(!s){s=document.createElement('style');s.id='noctalia-live';"
        "document.head.appendChild(s);}s.textContent=" + json.dumps(rule) + ";})()"
    )
    for t in targets:
        if t.get("type") == "page" and "tidal.com" in t.get("url", ""):
            ws = websocket.create_connection(t["webSocketDebuggerUrl"], timeout=3)
            ws.send(json.dumps({"id": 1, "method": "Runtime.evaluate",
                                "params": {"expression": js}}))
            ws.recv()
            ws.close()
  '';
in
{
  home.packages = [ tidalLiveTheme ];

  # ── GTK ──────────────────────────────────────────────────────────────────────
  gtk = {
    enable = true;
    theme = {
      name    = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name    = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
  };

  # ── Cursor ───────────────────────────────────────────────────────────────────
  # enable must be explicit — home-manager deprecated inferring it from the
  # attrset being defined (warning added upstream in home-cursor.nix).
  home.pointerCursor = {
    enable     = true;
    gtk.enable = true;
    name       = "Bibata-Modern-Ice";
    package    = pkgs.bibata-cursors;
    size       = 24;
  };

  # qt block intentionally disabled: qt.style injects QT_STYLE_OVERRIDE=kvantum,
  # which black-screens plasmashell (Kirigami QML-imports it). Re-test per Plasma bump.
}
