# Per-app home-manager config: git, neovim, OBS, pywalfox, RAW-photo mime
# defaults, and desktop-entry overrides (Signal keyring pin, Vesktop VPN
# bypass).
{ pkgs, ... }:

{
  # ── Pywalfox native messaging host ───────────────────────────────────────────
  # Registers pywalfox-native with Zen (and any Gecko browser) without needing
  # programs.firefox.enable, which would pull Firefox in alongside Zen.
  home.file.".mozilla/native-messaging-hosts/pywalfox.json".text =
    builtins.toJSON {
      name                = "pywalfox";
      description         = "Pywalfox native app";
      path                = "${pkgs.pywalfox-native}/bin/pywalfox";
      type                = "stdio";
      allowed_extensions  = [ "pywalfox@frewacom.org" ];
    };

  # ── Default apps (mime associations) ─────────────────────────────────────────
  # Canon RAW photos open in nomacs (built with libraw; loupe can't read them).
  # The association is declared here because nomacs' .desktop file doesn't
  # advertise the RAW mime types itself.
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
  # LazyVim manages plugins via lazy.nvim — nvim dotfiles are NOT deployed
  # declaratively (lazy-lock.json is written at runtime into ~/.config/nvim).
  # Clone/stow nvim dotfiles manually, or migrate to programs.neovim.plugins later.
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
  # Force gnome-libsecret so the keyring backend is consistent across all
  # compositors. Without this, Electron autodetects kwallet6 in KDE sessions and
  # falls back to basic_text in Niri/Mango/Hyprland — "keyring backend changed"
  # error loses the stored encryption key on every cross-session launch.
  xdg.desktopEntries.signal-desktop = {
    name       = "Signal";
    exec       = "signal-desktop --password-store=gnome-libsecret %U";
    icon       = "signal-desktop";
    comment    = "Private messaging from your desktop";
    categories = [ "Network" "InstantMessaging" "Chat" ];
    mimeType   = [ "x-scheme-handler/sgnl" "x-scheme-handler/signalcaptcha" ];
  };

  # ── Vesktop ──────────────────────────────────────────────────────────────────
  # Override the system .desktop entry so every launch path — KDE app menu,
  # Noctalia launcher, rofi, etc. — goes through mullvad-exclude. Without this,
  # Discord traffic bypasses the VPN tunnel and the app won't connect.
  # Compositor autostarts are handled separately:
  #   Mango/Niri: in the dotfiles autostart configs
  #   Hyprland:   exec-once in the NixOS additions block (home/dotfiles.nix)
  xdg.desktopEntries.vesktop = {
    name       = "Vesktop";
    exec       = "mullvad-exclude vesktop %U";
    icon       = "vesktop";
    comment    = "Vesktop — Discord via Mullvad split tunnel";
    categories = [ "Network" "InstantMessaging" "Chat" ];
    mimeType   = [ "x-scheme-handler/discord" ];
  };
}
