# GTK theme and icons, Nautilus sidebar pins, mouse cursor, Qt app style.
{ config, pkgs, ... }:

{
  # --- GTK theme and icons ---
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
    # Nautilus sidebar pins. Add them here; Ctrl+D in Nautilus won't stick.
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

  # --- Cursor ---
  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  # --- Qt apps ---
  # Qt apps take their colors from Noctalia through qt6ct.
  xdg.configFile."qt6ct/qt6ct.conf".text = ''
    [Appearance]
    style=Fusion
    custom_palette=true
    color_scheme_path=${config.xdg.configHome}/qt6ct/colors/noctalia.conf
    icon_theme=Papirus-Dark
  '';
}
