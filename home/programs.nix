# Per-app home-manager config: git, neovim, OBS, pywalfox, RAW mime defaults,
# and desktop-entry overrides (Signal keyring pin, Vesktop VPN bypass).
{ pkgs, ... }:

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
    defaultApplications = {
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

  # ── Signal ───────────────────────────────────────────────────────────────────
  # Force gnome-libsecret: Electron otherwise picks a different keyring per
  # compositor and "keyring backend changed" loses the encryption key.
  xdg.desktopEntries.signal-desktop = {
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
}
