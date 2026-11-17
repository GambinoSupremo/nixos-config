# Programs installed for everyone. Anything with its own settings block
# (Steam, fish, OBS...) is switched on where those settings live instead.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [

    # --- Terminal ---
    ghostty
    eza
    ripgrep
    fd
    tree
    less
    wget
    curl

    # --- Files ---
    rsync
    unrar
    unzip

    # --- Editors ---
    neovim # here as well as in home/, so root has it for repairs
    nano
    zed-editor

    # --- Dev tools ---
    git
    github-cli
    nil # Nix language server for Zed
    jq
    python3
    # Keeper Commander isn't in nixpkgs, so run a pinned release through uv.
    # Python 3.13 because one of its parts has no 3.14 build yet.
    (writeShellScriptBin "keeper" ''
      exec ${uv}/bin/uv tool run --no-python-downloads --python ${python313}/bin/python3.13 \
        --exclude-newer 2026-10-09T00:00:00Z --from keepercommander==18.1.8 keeper "$@"
    '')

    # --- System info ---
    fastfetch
    dmidecode
    smartmontools
    usbutils
    pciutils # lspci
    ddcutil # monitor settings
    dnsutils # dig, nslookup

    # --- Desktop tools ---
    cliphist
    grim
    slurp
    wl-clipboard
    hyprshutdown # clean logout on Ctrl+Alt+Delete
    glib.bin # gsettings
    wlr-randr
    wtype
    wev
    playerctl
    xrandr

    # --- Themes ---
    bibata-cursors
    papirus-icon-theme
    adw-gtk3
    qt6Packages.qt6ct
    kdePackages.breeze
    # No kvantum here: it black-screened Plasma (docs/decisions.md).

    # --- Apps ---
    obsidian
    pcloud
    signal-desktop
    vesktop # Discord
    mpv
    nomacs # image viewer
    nautilus
    gnome-disk-utility
    pavucontrol
    qbittorrent
    matugen # colors from the wallpaper
    firefox
    tutanota-desktop

    # --- Music ---
    spotify
    sone # TIDAL

    # --- Gaming ---
    protonplus

    # Mullvad comes from its service (networking.nix). Don't add pkgs.mullvad:
    # it's an older build and would replace the mullvad command.

    pywalfox-native # lets Zen follow the theme colors
  ];
}
