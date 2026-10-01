# Per-app home-manager config: git, neovim, OBS, pywalfox, RAW mime defaults,
# and desktop-entry overrides (Signal keyring pin, Vesktop VPN bypass).
{ config, pkgs, lib, ... }:

{
  # ── Pywalfox native messaging host ───────────────────────────────────────────
  # Registers pywalfox-native with Zen without programs.firefox.enable
  # (which would pull Firefox in alongside Zen).
  home.file.".mozilla/native-messaging-hosts/pywalfox.json".text =
    builtins.toJSON {
      name                = "pywalfox";
      description         = "Pywalfox native app";
      path                = "${pkgs.pywalfox-native}/bin/pywalfox";
      type                = "stdio";
      allowed_extensions  = [ "pywalfox@frewacom.org" ];
    };

  # ── Default apps (mime associations) ─────────────────────────────────────────
  # Canon RAW opens in nomacs (loupe can't read it); declared here because
  # nomacs' .desktop doesn't advertise the RAW mime types.
  xdg.mimeApps = {
    enable = true;
    associations.added = {
      "image/x-canon-cr2" = [ "org.nomacs.ImageLounge.desktop" ];
      "image/x-canon-cr3" = [ "org.nomacs.ImageLounge.desktop" ];
    };
    # Text/code in Zed; mkForce beats zen's setAsDefaultBrowser claim on text/plain + json.
    defaultApplications = lib.genAttrs [
      "text/plain" "text/markdown" "text/x-log" "text/csv"
      "text/x-nix" "text/x-python" "text/x-shellscript" "application/x-shellscript"
      "text/x-csrc" "text/x-chdr" "text/x-c++src" "text/rust" "text/javascript"
      "application/json" "application/toml" "application/x-yaml" "application/xml"
      "text/x-ini" "application/x-zerosize"
    ] (_: lib.mkForce [ "dev.zed.Zed.desktop" ]) // {
      # Folders (e.g. Steam "Browse local files") — otherwise falls back to kitty-open.
      "inode/directory"   = [ "org.gnome.Nautilus.desktop" ];
      "image/x-canon-cr2" = [ "org.nomacs.ImageLounge.desktop" ];
      "image/x-canon-cr3" = [ "org.nomacs.ImageLounge.desktop" ];
    };
  };

  # ── Git ──────────────────────────────────────────────────────────────────────
  programs.git = {
    enable   = true;
    settings = {
      user.name            = "Gavin";
      user.email           = "service.haiku882@passinbox.com";
      init.defaultBranch   = "main";
      push.autoSetupRemote = true;
    };
  };

  # ── Neovim ───────────────────────────────────────────────────────────────────
  # nvim dotfiles NOT deployed declaratively — lazy.nvim writes lazy-lock.json
  # at runtime; clone/stow them manually.
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    vimAlias      = true;
  };

  # ── OBS Studio ───────────────────────────────────────────────────────────────
  # obs-vaapi → VA-API (NVDEC) encoding; obs-vkcapture → GPU-side game capture.
  programs.obs-studio = {
    enable  = true;
    plugins = with pkgs.obs-studio-plugins; [
      obs-vaapi
      obs-vkcapture
    ];
  };

  # ── Satty ────────────────────────────────────────────────────────────────────
  # Noctalia pipes region screenshots here (shell.screenshot in noctalia config.toml).
  # Enter copies + exits, Ctrl+S saves to output-filename.
  programs.satty = {
    enable   = true;
    settings.general = {
      fullscreen        = false;
      early-exit        = true;
      copy-command      = "wl-copy";
      corner-roundness  = 12;
      initial-tool      = "arrow";
      output-filename   = "${config.home.homeDirectory}/Pictures/Screenshots/Screenshot-%Y-%m-%d_%H-%M-%S.png";
    };
  };

  # ── Signal ───────────────────────────────────────────────────────────────────
  # Pin gnome-libsecret (key lives there); id "signal" replaces the package entry.
  xdg.desktopEntries.signal = {
    name       = "Signal";
    exec       = "signal-desktop --password-store=gnome-libsecret %U";
    icon       = "signal-desktop";
    comment    = "Private messaging from your desktop";
    categories = [ "Network" "InstantMessaging" "Chat" ];
    mimeType   = [ "x-scheme-handler/sgnl" "x-scheme-handler/signalcaptcha" ];
  };

  # ── Vesktop ──────────────────────────────────────────────────────────────────
  # Every launcher path goes through mullvad-exclude or Discord won't connect.
  # Compositor autostarts handle themselves (dotfiles / home/dotfiles.nix).
  xdg.desktopEntries.vesktop = {
    name       = "Vesktop";
    exec       = "mullvad-exclude vesktop %U";
    icon       = "vesktop";
    comment    = "Vesktop — Discord via Mullvad split tunnel";
    categories = [ "Network" "InstantMessaging" "Chat" ];
    mimeType   = [ "x-scheme-handler/discord" ];
  };

  # ── Sunshine ─────────────────────────────────────────────────────────────────
  # Runs as a user service; the menu entry opens the web UI instead of a 2nd copy.
  xdg.desktopEntries."dev.lizardbyte.app.Sunshine" = {
    name       = "Sunshine";
    exec       = "xdg-open https://localhost:47990";
    icon       = "dev.lizardbyte.app.Sunshine";
    comment    = "Sunshine web UI";
    categories = [ "RemoteAccess" "Network" ];
  };
}
