# Programs installed for everyone. Anything with its own settings block
# (Steam, fish, OBS...) is switched on where those settings live instead.
{ pkgs, ... }:

let
  # Sone 0.23 never refetches cached mixes (Daily Discovery lags ~28h); clear them on each launch.
  soneLauncher = pkgs.writeShellScriptBin "sone" ''
    for m in "$HOME"/.config/sone/cache/v7/dynamic/*.meta; do
      ${pkgs.gnugrep}/bin/grep -qs '"mix-page"' "$m" && rm -f -- "$m" "''${m%.meta}.dat"
    done
    exec ${pkgs.sone}/bin/sone "$@"
  '';
  soneFreshMixes = pkgs.symlinkJoin {
    name = "sone-fresh-mixes";
    paths = [
      soneLauncher
      pkgs.sone
    ];
  };
in
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
    nil # Nix language server for Neovim
    nixd # Nix language server for Zed (NixOS + Home Manager option docs)
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
    protonmail-desktop
    pinta # simple image editor
    libreoffice
    xournalpp # sign / write on PDFs

    # --- Music ---
    # Spotify: home/apps/spotify.nix (themed copy)
    soneFreshMixes # TIDAL

    # --- Creative / Game dev ---
    blender
    godot

    # --- Gaming ---
    protonplus
    heroic # Epic, GOG and Amazon games

    # Mullvad comes from its service (networking.nix). Don't add pkgs.mullvad:
    # it's an older build and would replace the mullvad command.
  ];
}
