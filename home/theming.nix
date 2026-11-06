{ config, pkgs, ... }:

{
  # ── GTK ──────────────────────────────────────────────────────────────────────
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    # Nautilus sidebar pins; file is a read-only symlink, so add pins here, not via Ctrl+D.
    gtk3.bookmarks = [
      "smb://gavin@10.0.0.117/plexmedia NAS"
      "smb://gavin@10.0.0.117/Personal Personal NAS"
      "file://${config.home.homeDirectory}/Downloads"
      "file://${config.home.homeDirectory}/Documents"
      "file://${config.home.homeDirectory}/Pictures"
      "file://${config.home.homeDirectory}/Games"
      "file://${config.home.homeDirectory}/Projects"
    ];
  };

  # ── Cursor ───────────────────────────────────────────────────────────────────
  # enable must be explicit — home-manager deprecated inferring it from the
  # attrset being defined (warning added upstream in home-cursor.nix).
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  # qt block intentionally disabled: qt.style injects QT_STYLE_OVERRIDE=kvantum
  # session-wide (it black-screened plasmashell back when Plasma was installed).

  # Every Qt 6 app reads this: the dotfiles set QT_QPA_PLATFORMTHEME=qt6ct for the session.
  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    style=Fusion
    custom_palette=true
    color_scheme_path=${config.xdg.configHome}/qt6ct/colors/noctalia.conf
    icon_theme=Papirus-Dark
  '';
}
