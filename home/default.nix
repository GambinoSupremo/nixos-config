{ config, pkgs, inputs, lib, ... }:

{
  imports = [
    inputs.noctalia.homeModules.default
  ];

  home.username = "gav";
  home.homeDirectory = "/home/gav";
  home.stateVersion = "24.05";
  programs.home-manager.enable = true;

  # ── Noctalia Shell ────────────────────────────────────────────────────────────
  programs.noctalia-shell = {
    enable = true;
    settings = {
      wallpaper = {
        enabled = true;
        directory = "/home/gav/Pictures/backgrounds";
        automationEnabled = true;
        wallpaperChangeMode = "random";
        randomIntervalSec = 2700;
      };
      appLauncher = {
        iconMode = "tabler";
        terminalCommand = "ghostty --";
        enableClipboardHistory = true;
        sortByMostUsed = true;
      };
      colorSchemes = {
        darkMode = true;
      };
    };
  };

  # ── Shell & Terminal ────────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting ""
    '';
    shellAliases = {
      ls = "eza --icons --group-directories-first";
      cat = "bat --style=plain";
      grep = "rg";
    };
  };

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      palette = "noctalia";
      palettes.noctalia = {
        purple = "#bd93f9";
        cyan = "#8be9fd";
      };
      character = {
        success_symbol = "[❯](cyan)";
        error_symbol = "[❯](red)";
      };
      os = { disabled = false; };
      git_metrics = { disabled = false; };
      line_break = { disabled = false; };
    };
  };

  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "MesloLGS Nerd Font";
      font-size = 12;
      background-opacity = 0.7;
      window-decoration = false;
      cursor-style = "block";
      window-padding-x = 12;
      window-padding-y = 12;
      keybind = [ "ctrl+c=copy_to_clipboard" "ctrl+v=paste_from_clipboard" ];
      command = "fish -C 'pokemon-colorscripts --no-title -r 2>/dev/null || true'";
    };
  };

  programs.kitty = {
    enable = true;
    font = { name = "MesloLGS Nerd Font"; size = 12; };
    settings = {
      background_opacity = "0.7";
      window_padding_width = 12;
      hide_window_decorations = "yes";
    };
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    extraPackages = with pkgs; [ gcc ripgrep fd nodejs_22 python311 ];
  };

  programs.tmux = { enable = true; mouse = true; keyMode = "vi"; };
  programs.zoxide = { enable = true; enableFishIntegration = true; options = [ "--cmd cd" ]; };
  programs.fzf = { enable = true; enableFishIntegration = false; };
  programs.bat = { enable = true; config.theme = "base16"; };
  programs.eza = { enable = true; };
  programs.btop = { enable = true; };
  programs.yazi = { enable = true; enableFishIntegration = true; };

  programs.git = {
    enable = true;
    userName = "Gavin Turner";
    userEmail = "service.haiku882@passinbox.com";
    extraConfig = { credential.helper = "github"; };
  };
  programs.gh.enable = true;

  # ── GTK & Qt Theming ────────────────────────────────────────────────────────
  gtk = {
    enable = true;
    theme = { name = "adw-gtk3-dark"; package = pkgs.adw-gtk3; };
    iconTheme = { name = "Tela-pink-dark"; package = pkgs.tela-icon-theme; };
    cursorTheme = { name = "Bibata-Modern-Ice"; package = pkgs.bibata-cursors; size = 24; };
    font = { name = "Adwaita Sans"; size = 11; };
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      accent-color = "teal";
      font-antialiasing = "grayscale";
      font-hinting = "slight";
    };
  };

  qt = { enable = true; platformTheme.name = "qtct"; style.name = "kvantum"; };

  # ── Fonts & Packages ────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "Meslo" ]; })
    noto-fonts noto-fonts-cjk-sans noto-fonts-emoji
    liberation_ttf dejavu_fonts open-sans font-awesome

    sway labwc
    inputs.zen-browser.packages."${pkgs.system}".default
    vivaldi vesktop signal-desktop element-desktop telegram-desktop
    tidal-hifi cider spotify spicetify-cli mpv vlc obs-studio cava playerctl
    obsidian lunatask meld qbittorrent
    zed-editor ollama mullvad-vpn
    polychromatic input-remapper keyd
    fuzzel walker cliphist grim slurp wl-clipboard wtype wev
    nautilus zathura gnome-disk-utility
    duf glances fastfetch tree pv lsd
    matugen kvantum nwg-look papirus-icon-theme nordzy-icon-theme
    pavucontrol stow
  ];
}
