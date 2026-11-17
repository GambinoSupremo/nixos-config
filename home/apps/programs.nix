# Default applications, desktop launchers, OBS, and screenshots.
{
  config,
  pkgs,
  lib,
  ...
}:

{
  # ── Default apps (mime associations) ─────────────────────────────────────────
  # nomacs is the only image viewer; its .desktop doesn't advertise Canon RAW,
  # and satty claims png/jpeg, so the image defaults are pinned here.
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "image/x-canon-cr2" = [ "org.nomacs.ImageLounge.desktop" ];
      "image/x-canon-cr3" = [ "org.nomacs.ImageLounge.desktop" ];
    };
    # Text/code in Zed; mkForce beats zen's setAsDefaultBrowser claim on text/plain + json.
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
        # Folders (e.g. Steam "Browse local files") open in Nautilus, not whatever claims the type.
        "inode/directory" = [ "org.gnome.Nautilus.desktop" ];
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

  # ── OBS Studio ───────────────────────────────────────────────────────────────
  # obs-vaapi → VA-API encoding; obs-vkcapture → GPU-side game capture.
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-vaapi
      obs-vkcapture
    ];
  };

  # ── btop ─────────────────────────────────────────────────────────────────────
  # Uses the theme Noctalia writes to ~/.config/btop/themes/noctalia.theme.
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "noctalia";
      theme_background = false;
    };
  };

  # ── Satty ────────────────────────────────────────────────────────────────────
  # Noctalia pipes region screenshots here (shell.screenshot in noctalia config.toml).
  # Enter copies + exits, Ctrl+S saves to output-filename.
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

  # ── Signal ───────────────────────────────────────────────────────────────────
  # Pin gnome-libsecret (key lives there); id "signal" replaces the package entry.
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

  # ── Vesktop ──────────────────────────────────────────────────────────────────
  # Every launcher path goes through mullvad-exclude or Discord won't connect.
  # Compositor autostarts handle themselves (dotfiles / home/dotfiles.nix).
  xdg.desktopEntries.vesktop = {
    name = "Vesktop";
    exec = "mullvad-exclude vesktop %U";
    icon = "discord"; # Papirus round icon; its vesktop.svg is the rainbow Vencord logo
    comment = "Vesktop — Discord via Mullvad split tunnel";
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
    mimeType = [ "x-scheme-handler/discord" ];
  };

  # ── Sone ─────────────────────────────────────────────────────────────────────
  # Same id as the package entry (SONE.desktop) so it replaces it; findable as "Tidal".
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

  # ── Sunshine ─────────────────────────────────────────────────────────────────
  # Runs as a user service; the menu entry opens the web UI instead of a 2nd copy.
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

  # ── pCloud ───────────────────────────────────────────────────────────────────
  # pCloud writes its own launcher pointing at an old store path; hide it so only
  # the package's entry shows up.
  xdg.dataFile."applications/appimagekit-pcloud.desktop" = {
    force = true;
    text = "[Desktop Entry]\nHidden=true\n";
  };
}
