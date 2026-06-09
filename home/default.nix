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
      colorSchemes.darkMode = true;
    };
  };

  # ── Shell ─────────────────────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    interactiveShellInit = ''set fish_greeting ""'';
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
      os.disabled = false;
      git_metrics.disabled = false;
      line_break.disabled = false;
    };
  };

  # ── Terminals ─────────────────────────────────────────────────────────────────
  programs.ghostty = {
    enable = true;
    settings = {
      font-family = "MesloLGS Nerd Font";
      font-size = 12;
      background-opacity = 0.7;
      window-decoration = false;
      cursor-style = "block";
      cursor-style-blink = true;
      window-padding-x = 12;
      window-padding-y = 12;
      scrollback-limit = 3023;
      keybind = [
        "ctrl+c=copy_to_clipboard"
        "ctrl+v=paste_from_clipboard"
      ];
      command = "fish -C 'pokemon-colorscripts --no-title -r 2>/dev/null || true'";
    };
  };

  programs.kitty = {
    enable = true;
    font = {
      name = "MesloLGS Nerd Font";
      size = 12;
    };
    settings = {
      background_opacity = "0.7";
      window_padding_width = 12;
      hide_window_decorations = "yes";
    };
  };

  # ── Editors ───────────────────────────────────────────────────────────────────
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    extraPackages = with pkgs; [
      gcc
      ripgrep
      fd
      nodejs_22
      python3
    ];
  };

  # ── Dev tools ─────────────────────────────────────────────────────────────────
  programs.git = {
    enable = true;
    userName = "Gavin Turner";
    userEmail = "service.haiku882@passinbox.com";
    extraConfig.credential.helper = "github";
  };

  programs.gh.enable = true;

  # ── CLI utilities ─────────────────────────────────────────────────────────────
  programs.tmux = {
    enable = true;
    mouse = true;
    keyMode = "vi";
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
    options = [ "--cmd cd" ];
  };

  programs.fzf = {
    enable = true;
    enableFishIntegration = false;
  };

  programs.bat = {
    enable = true;
    config.theme = "base16";
  };

  programs.eza.enable = true;
  programs.btop.enable = true;

  programs.yazi = {
    enable = true;
    enableFishIntegration = true;
  };

  # ── GTK & Qt ──────────────────────────────────────────────────────────────────
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name = "Tela-pink-dark";
      package = pkgs.tela-icon-theme;
    };
    cursorTheme = {
      name = "Bibata-Modern-Ice";
      package = pkgs.bibata-cursors;
      size = 24;
    };
    font = {
      name = "Adwaita Sans";
      size = 11;
    };
  };

  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme = "prefer-dark";
    accent-color = "teal";
    font-antialiasing = "grayscale";
    font-hinting = "slight";
  };

  qt = {
    enable = true;
    platformTheme.name = "qtct";
    style.name = "kvantum";
    style.package = pkgs.kdePackages.qtstyleplugin-kvantum;
  };

  # ── WM configs from dotfiles repo ─────────────────────────────────────────────
  xdg.configFile = {
    # Niri: patch config.kdl so noctalia.kdl includes are optional.
    # Noctalia writes ~/.config/niri/noctalia.kdl at runtime.
    "niri/config.kdl" = {
      source = pkgs.runCommand "niri-config.kdl" {} ''
        sed 's|^include "./noctalia.kdl"|include optional=true "./noctalia.kdl"|g' \
          ${inputs.dotfiles}/niri/config.kdl > $out
      '';
      force = true;
    };

    "niri/binds.kdl" = {
      source = "${inputs.dotfiles}/niri/binds.kdl";
      force = true;
    };

    "niri/windowrules.kdl" = {
      source = "${inputs.dotfiles}/niri/windowrules.kdl";
      force = true;
    };

    "niri/alttab.kdl" = {
      source = "${inputs.dotfiles}/niri/alttab.kdl";
      force = true;
    };

    "niri/outputs.kdl" = {
      source = "${inputs.dotfiles}/niri/outputs.kdl";
      force = true;
    };

    # Mango: autostart.conf patches out the Arch-specific portal exec-once.
    # bind.conf patches out the hardcoded /usr/bin/ghostty path.
    "mango/config.conf" = {
      source = "${inputs.dotfiles}/mango/config.conf";
      force = true;
    };

    "mango/monitor.conf" = {
      source = "${inputs.dotfiles}/mango/monitor.conf";
      force = true;
    };

    "mango/tag.conf" = {
      source = "${inputs.dotfiles}/mango/tag.conf";
      force = true;
    };

    "mango/rule.conf" = {
      source = "${inputs.dotfiles}/mango/rule.conf";
      force = true;
    };

    "mango/env.conf" = {
      source = "${inputs.dotfiles}/mango/env.conf";
      force = true;
    };

    "mango/autostart.conf" = {
      source = pkgs.runCommand "mango-autostart.conf" {} ''
        grep -v '/usr/lib/xdg-desktop-portal' \
          ${inputs.dotfiles}/mango/autostart.conf > $out
      '';
      force = true;
    };

    "mango/bind.conf" = {
      source = pkgs.runCommand "mango-bind.conf" {} ''
        sed 's|/usr/bin/ghostty|ghostty|g' \
          ${inputs.dotfiles}/mango/bind.conf > $out
      '';
      force = true;
    };

    # Hyprland — deploy all lua config files from dotfiles.
    # noctalia.lua and noctalia/noctalia-colors.conf are runtime files.
    # These temporary stubs keep require("noctalia") from failing before
    # Noctalia writes its real runtime module.
    "hypr/hyprland.conf" = {
      source = pkgs.runCommand "hyprland.conf" {} ''
        cat ${inputs.dotfiles}/hypr/hyprland.conf > $out
        echo "" >> $out
        echo "source = ~/.config/hypr/noctalia-start.conf" >> $out
      '';
      force = true;
    };

    "hypr/noctalia-start.conf" = {
      text = ''
        exec-once = ${inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/noctalia-shell
      '';
      force = true;
    };

    "hypr/noctalia.lua" = {
      text = ''
        local proxy = {}

        local mt = {
          __index = function(_, _)
            return proxy
          end,
          __call = function(_, ...)
            return nil
          end,
          __tostring = function()
            return ""
          end
        }

        setmetatable(proxy, mt)

        return proxy
      '';
      force = true;
    };

    "hypr/noctalia/init.lua" = {
      text = ''
        local proxy = {}

        local mt = {
          __index = function(_, _)
            return proxy
          end,
          __call = function(_, ...)
            return nil
          end,
          __tostring = function()
            return ""
          end
        }

        setmetatable(proxy, mt)

        return proxy
      '';
      force = true;
    };

    "hypr/hyprland.lua" = {
      source = pkgs.runCommand "hyprland.lua" {} ''
        sed \
          -e 's|require("noctalia")|pcall(require, "noctalia")|g' \
          -e "s|require('noctalia')|pcall(require, 'noctalia')|g" \
          ${inputs.dotfiles}/hypr/hyprland.lua > $out
      '';
      force = true;
    };

    "hypr/autostart.lua" = {
      source = "${inputs.dotfiles}/hypr/autostart.lua";
      force = true;
    };

    "hypr/bind.lua" = {
      source = "${inputs.dotfiles}/hypr/bind.lua";
      force = true;
    };

    "hypr/config.lua" = {
      source = "${inputs.dotfiles}/hypr/config.lua";
      force = true;
    };

    "hypr/env.lua" = {
      source = "${inputs.dotfiles}/hypr/env.lua";
      force = true;
    };

    "hypr/monitor.lua" = {
      source = "${inputs.dotfiles}/hypr/monitor.lua";
      force = true;
    };

    "hypr/rule.lua" = {
      source = "${inputs.dotfiles}/hypr/rule.lua";
      force = true;
    };

    "hypr/theme.lua" = {
      source = "${inputs.dotfiles}/hypr/theme.lua";
      force = true;
    };

    "hypr/workspaces.lua" = {
      source = "${inputs.dotfiles}/hypr/workspaces.lua";
      force = true;
    };
  };

  # ── Packages ──────────────────────────────────────────────────────────────────
  home.packages = with pkgs; [
    inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default

    nerd-fonts.meslo-lg
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-color-emoji
    liberation_ttf
    dejavu_fonts
    open-sans
    font-awesome

    sway
    labwc
    inputs.zen-browser.packages."${pkgs.system}".default
    vivaldi
    vesktop
    signal-desktop
    element-desktop
    telegram-desktop
    spotify
    mpv
    vlc
    obs-studio
    cava
    playerctl
    obsidian
    meld
    qbittorrent
    zed-editor
    ollama
    mullvad-vpn
    polychromatic
    input-remapper
    fuzzel
    cliphist
    grim
    slurp
    wl-clipboard
    wtype
    wev
    nautilus
    zathura
    gnome-disk-utility
    duf
    glances
    fastfetch
    tree
    pv
    lsd
    matugen
    kdePackages.qtstyleplugin-kvantum
    nwg-look
    papirus-icon-theme
    nordzy-icon-theme
    pavucontrol
    stow
    pokemon-colorscripts
  ];

  home.activation.clearConflicts = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ -z "$HOME" ] || [ "$HOME" = "/" ]; then
      echo "Refusing to clear Home Manager conflicts with unsafe HOME=$HOME" >&2
      exit 1
    fi

    for target in \
      ".gtkrc-2.0" \
      ".gtkrc" \
      ".config/gtk-3.0/settings.ini" \
      ".config/gtk-4.0/settings.ini" \
      ".config/niri/config.kdl" \
      ".config/niri/binds.kdl" \
      ".config/niri/windowrules.kdl" \
      ".config/niri/alttab.kdl" \
      ".config/niri/outputs.kdl" \
      ".config/mango/config.conf" \
      ".config/mango/monitor.conf" \
      ".config/mango/tag.conf" \
      ".config/mango/rule.conf" \
      ".config/mango/env.conf" \
      ".config/mango/autostart.conf" \
      ".config/mango/bind.conf" \
      ".config/hypr/hyprland.conf" \
      ".config/hypr/noctalia-start.conf" \
      ".config/hypr/noctalia.lua" \
      ".config/hypr/noctalia/init.lua" \
      ".config/hypr/hyprland.lua" \
      ".config/hypr/autostart.lua" \
      ".config/hypr/bind.lua" \
      ".config/hypr/config.lua" \
      ".config/hypr/env.lua" \
      ".config/hypr/monitor.lua" \
      ".config/hypr/rule.lua" \
      ".config/hypr/theme.lua" \
      ".config/hypr/workspaces.lua"
    do
      case "$target" in
        ""|"."|"/"|/*|../*|*/../*)
          echo "Refusing to remove unsafe Home Manager target: $target" >&2
          exit 1
          ;;
      esac

      rm -rf -- "$HOME/$target"
    done
  '';
}
