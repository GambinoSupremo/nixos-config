{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    # Noctalia home-manager module — provides programs.noctalia-shell.*
    inputs.noctalia.homeModules.default
  ];

  home.username      = "gav";
  home.homeDirectory = "/home/gav";
  home.stateVersion  = "25.05";
  programs.home-manager.enable = true;

  # ── Noctalia shell ────────────────────────────────────────────────────────────
  # NOTE: systemd startup is deprecated in Noctalia v5.
  # Do NOT use `qs -c noctalia-shell` or `killall qs` anymore.
  # Noctalia is started via compositor spawn-at-startup (see niri/mango configs).
  # IPC calls are now `noctalia-shell ipc call <component> <action>` (not qs).
  programs.noctalia-shell = {
    enable = true;

    settings = {
      # ── Wallpaper ────────────────────────────────────────────────────────────
      wallpaper = {
        enabled          = true;
        directory        = "/home/gav/Pictures/backgrounds";
        automationEnabled    = true;
        wallpaperChangeMode  = "random";
        randomIntervalSec    = 2700;   # your configured cycle interval
        # Noctalia uses connector names here, not identity strings.
        # If Nvidia renames ports after a driver update, update these values.
        # enableMultiMonitorDirectories = true;  # if you want per-monitor dirs
      };

      # ── App launcher ─────────────────────────────────────────────────────────
      appLauncher = {
        iconMode       = "tabler";  # avoids broken icons for reverse-DNS app IDs
        terminalCommand = "ghostty --";
        enableClipboardHistory = true;
        sortByMostUsed = true;
      };

      # ── General ───────────────────────────────────────────────────────────────
      general = {
        telemetryEnabled = false;
      };

      # ── Color scheme ─────────────────────────────────────────────────────────
      colorSchemes = {
        darkMode     = true;
        # useWallpaperColors = true;  # enable if you want matugen-style auto colors
        # predefinedScheme = "Noctalia (default)";
      };
    };

    # ── Wallpaper per-monitor declarative config ──────────────────────────────
    # Uses connector names as seen by the compositor (not identity strings).
    # Verify these after boot with: niri msg outputs
    # (Nvidia may rename DP-1/DP-2 after driver updates — update accordingly)
    # home.file.".cache/noctalia/wallpapers.json" is set below.
  };

  # Wallpaper JSON — set separately since it's a cache file, not a settings file.
  # Adjust connector names after verifying with `niri msg outputs` or `wlr-randr`.
  home.file.".cache/noctalia/wallpapers.json" = {
    text = builtins.toJSON {
      defaultWallpaper = "/home/gav/Pictures/backgrounds/apeiros";
      wallpapers = {
        # Replace with your actual connector names as reported by the compositor
        # "DP-2" = "/home/gav/Pictures/backgrounds/dreamcore";
        # "DP-1" = "/home/gav/Pictures/backgrounds/chillop";
      };
    };
  };

  # ── Fish ─────────────────────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting ""
      # pokemon-colorscripts on launch
      # pokemon-colorscripts --no-title -r 2>/dev/null || true
    '';
    shellAliases = {
      ls   = "eza --icons --group-directories-first";
      la   = "eza -la --icons --group-directories-first";
      ll   = "eza -l --icons --group-directories-first";
      tree = "eza --tree --icons --group-directories-first";
      cat  = "bat --style=plain";
      grep = "rg";
    };
  };

  # ── Starship ──────────────────────────────────────────────────────────────────
  programs.starship = {
    enable                = true;
    enableFishIntegration = true;
    # settings = builtins.fromTOML (builtins.readFile ./starship.toml);
  };

  # ── fzf ───────────────────────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    # Fish integration disabled — it binds Ctrl+T which conflicts with
    # Fish's built-in transpose-chars. Handled manually: bind ctrl-t fzf-file-widget
    enableFishIntegration = false;
  };

  # ── zoxide ────────────────────────────────────────────────────────────────────
  programs.zoxide = {
    enable                = true;
    enableFishIntegration = true;
  };

  # ── bat ───────────────────────────────────────────────────────────────────────
  programs.bat = {
    enable = true;
    config = {
      theme = "base16";
      style = "plain";
    };
  };

  # ── Git ───────────────────────────────────────────────────────────────────────
  programs.git = {
    enable      = true;
    userName    = "Gavin";
    userEmail   = "";
    extraConfig = {
      init.defaultBranch   = "main";
      push.autoSetupRemote = true;
    };
  };

  # ── Neovim ────────────────────────────────────────────────────────────────────
  # LazyVim manages plugins via lazy.nvim — let stow handle ~/.config/nvim for now.
  # Migrate to home-manager's programs.neovim.plugins only when you want lockfile
  # reproducibility (i.e., pin plugin versions in the flake).
  programs.neovim = {
    enable        = true;
    defaultEditor = true;
    vimAlias      = true;
  };

  # ── OBS Studio plugins ────────────────────────────────────────────────────────
  # programs.obs-studio = {
  #   enable  = true;
  #   plugins = with pkgs.obs-studio-plugins; [
  #     obs-vaapi
  #     obs-vkcapture
  #   ];
  # };

  # ── Stow / dotfiles coexistence note ─────────────────────────────────────────
  # Stow and home-manager coexist as long as they don't manage the same path.
  # Suggested migration order:
  #   1. starship, bat, zoxide (done above)
  #   2. fish conf.d → interactiveShellInit / shellAliases (done above)
  #   3. git, ssh
  #   4. niri config → programs.niri.settings (once you want it declarative)
  #   5. noctalia settings → programs.noctalia-shell.settings (done above)
  #   6. neovim (last — LazyVim adds complexity)
}
