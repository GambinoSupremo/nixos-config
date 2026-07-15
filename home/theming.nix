{ pkgs, ... }:

{
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

  # qt home-manager block intentionally disabled. Setting qt.style globally
  # injects QT_STYLE_OVERRIDE=kvantum, which makes KDE's QML code (Kirigami,
  # KWin effects, plasmashell wallpaper) try to import "kvantum" as a QML
  # module — it's not on KDE's QML path → black screen. KDE manages its own
  # Qt style (Breeze). All three compositors currently set
  # QT_QPA_PLATFORMTHEME=kde in their env configs (mango/env.conf,
  # niri/config.kdl environment block, hypr/env.lua) — kvantum is not in
  # use anywhere. Re-test the black-screen behavior after each Plasma major
  # bump; if Kirigami stops probing kvantum, qt.style can come back.
}
