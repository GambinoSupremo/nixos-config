# Which app opens what, a few app settings, and fixed-up launcher entries.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # --- Default apps ---
  # Text and code open in Zed, folders in Nautilus, images in nomacs,
  # email links in Proton Mail.
  xdg.mimeApps = {
    enable = true;
    # nomacs doesn't say it can open Canon RAW, so tell it here.
    associations.added = {
      "image/x-canon-cr2" = [ "org.nomacs.ImageLounge.desktop" ];
      "image/x-canon-cr3" = [ "org.nomacs.ImageLounge.desktop" ];
    };
    # mkForce: Zen also wants text and json.
    defaultApplications =
      lib.genAttrs [
        "text/plain"
        "text/markdown"
        "text/x-log"
        "text/csv"
        "text/x-nix"
        "text/x-python"
        "text/x-shellscript"
        "application/x-shellscript"
        "text/x-csrc"
        "text/x-chdr"
        "text/x-c++src"
        "text/rust"
        "text/javascript"
        "application/json"
        "application/toml"
        "application/x-yaml"
        "application/xml"
        "text/x-ini"
        "application/x-zerosize"
      ] (_: lib.mkForce [ "dev.zed.Zed.desktop" ])
      // {
        "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
        "x-scheme-handler/mailto" = [ "proton-mail.desktop" ];
      }
      // lib.genAttrs [
        "image/png"
        "image/jpeg"
        "image/webp"
        "image/gif"
        "image/tiff"
        "image/x-canon-cr2"
        "image/x-canon-cr3"
      ] (_: [ "org.nomacs.ImageLounge.desktop" ]);
  };

  # --- App settings ---
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-vaapi # GPU encoding
      obs-vkcapture # game capture
    ];
  };

  # Colors come from the theme Noctalia writes.
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "noctalia";
      theme_background = false;
    };
  };

  # Screenshot editor: Enter copies and closes, Ctrl+S saves.
  programs.satty = {
    enable = true;
    settings.general = {
      fullscreen = false;
      early-exit = true;
      copy-command = "wl-copy";
      corner-roundness = 12;
      initial-tool = "arrow";
      output-filename = "${config.home.homeDirectory}/Pictures/Screenshots/Screenshot-%Y-%m-%d_%H-%M-%S.png";
    };
  };

  # --- Launcher entries ---
  # Each one replaces the entry the app ships with.

  # Signal's key is in the GNOME keyring, so always start it with that.
  xdg.desktopEntries.signal = {
    name = "Signal";
    exec = "signal-desktop --password-store=gnome-libsecret %U";
    icon = "signal-desktop";
    comment = "Private messaging from your desktop";
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
    mimeType = [
      "x-scheme-handler/sgnl"
      "x-scheme-handler/signalcaptcha"
    ];
  };

  # Discord only connects outside the VPN.
  xdg.desktopEntries.vesktop = {
    name = "Vesktop";
    exec = "mullvad-exclude vesktop %U";
    icon = "discord"; # the round Discord icon, not the rainbow Vencord one
    comment = "Vesktop — Discord via Mullvad split tunnel";
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
    mimeType = [ "x-scheme-handler/discord" ];
  };

  # Searching "Tidal" finds Sone.
  xdg.desktopEntries.SONE = {
    name = "Sone";
    genericName = "Tidal";
    exec = "sone";
    icon = "sone";
    comment = "TIDAL music player";
    categories = [
      "AudioVideo"
      "Audio"
      "Music"
    ];
    mimeType = [ "x-scheme-handler/tidal" ];
    settings = {
      Keywords = "tidal;music;";
      StartupWMClass = "sone";
    };
  };

  # Sunshine already runs in the background; this opens its web page.
  xdg.desktopEntries."dev.lizardbyte.app.Sunshine" = {
    name = "Sunshine";
    exec = "xdg-open https://localhost:47990";
    icon = "dev.lizardbyte.app.Sunshine";
    comment = "Sunshine web UI";
    categories = [
      "RemoteAccess"
      "Network"
    ];
  };

  # pCloud adds a second, broken launcher of its own; hide it.
  xdg.dataFile."applications/appimagekit-pcloud.desktop" = {
    force = true;
    text = "[Desktop Entry]\nHidden=true\n";
  };
}
