{ config, pkgs, inputs, lib, ... }:
let
  zen = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  environment.systemPackages = with pkgs; [
    # Shell / Terminal
    ghostty kitty starship tmux bat eza fzf zoxide
    ripgrep fd tree duf less pv wget curl

    # File management
    stow rsync unrar unzip lsd

    # Editors
    neovim vim nano meld zed-editor

    # Dev tools
    git github-cli cmake ninja python3

    # System utilities
    btop glances fastfetch dmidecode lsscsi
    hdparm smartmontools sg3_utils usbutils hwinfo

    # Wayland tooling
    cliphist grim slurp wl-clipboard wtype wev
    playerctl fuzzel xrandr wayland-protocols

    # Themes / Appearance
    nwg-look bibata-cursors papirus-icon-theme
    tela-icon-theme adw-gtk3
    kdePackages.qtstyleplugin-kvantum
    libsForQt5.qtstyleplugin-kvantum
    qt6Packages.qt6ct

    # Applications
    obsidian signal-desktop vesktop element-desktop
    vivaldi zen mpv vlc loupe nautilus
    gnome-disk-utility pavucontrol qbittorrent matugen

    # Media
    spotify

    # Gaming / Streaming
    obs-studio protonplus

    # Peripherals
    polychromatic

    # Python
    python3Packages.defusedxml
    python3Packages.packaging
  ];
}
