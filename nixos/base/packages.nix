# System-wide packages; anything owned by a NixOS module or HM programs.* is
# deliberately absent. git + neovim duplicated on purpose for root/TTY recovery.
{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [

    # ── Shell / Terminal ──────────────────────────────────────────────────────
    # fish registered system-wide via programs.fish in users.nix
    # starship / bat / fzf / zoxide: HM-owned — home/shell.nix
    ghostty
    eza # stays: only aliased (no programs.eza) in home/shell.nix
    ripgrep
    fd
    tree
    less
    wget
    curl

    # ── File management ───────────────────────────────────────────────────────
    rsync
    unrar
    unzip

    # ── Editors ───────────────────────────────────────────────────────────────
    neovim
    vim
    nano
    zed-editor

    # ── Dev tools ─────────────────────────────────────────────────────────────
    git
    github-cli
    nil # Nix language server — Zed's Nix extension shells out to it
    jq # JSON CLI; required by niri
    python3
    # Keeper Commander CLI; not in nixpkgs. Pinned release, deps resolved as of its
    # release date. Python 3.13 because keeper-mlkem has no 3.14 wheel yet.
    (writeShellScriptBin "keeper" ''
      exec ${uv}/bin/uv tool run --no-python-downloads --python ${python313}/bin/python3.13 \
        --exclude-newer 2026-10-09T00:00:00Z --from keepercommander==18.1.8 keeper "$@"
    '')

    # ── System utilities ──────────────────────────────────────────────────────
    btop
    fastfetch
    dmidecode
    smartmontools
    usbutils

    # ── Wayland tooling ───────────────────────────────────────────────────────
    # niri registered via programs.niri in desktop.nix
    cliphist
    grim
    slurp
    wl-clipboard
    wlr-randr
    wtype
    wev
    playerctl
    fuzzel
    xwayland-satellite # rootless Xwayland for pure-Wayland compositors
    xrandr
    # noctalia — v5, managed by the upstream HM module (programs.noctalia)
    #            in home/default.nix; runs as noctalia.service

    # ── Themes / Appearance ───────────────────────────────────────────────────
    bibata-cursors # was bibata-cursor-theme-bin (AUR)
    papirus-icon-theme
    adw-gtk3 # was adw-gtk-theme
    qt6Packages.qt6ct # top-level qt6ct became a throw alias 2025-10-27
    kdePackages.breeze # was breeze
    # kvantum intentionally NOT system-wide: Plasma's Kirigami QML-imports it and
    # black-screens plasmashell. Want it elsewhere? Per-user + QT_STYLE_OVERRIDE.

    # ── Applications ─────────────────────────────────────────────────────────
    obsidian
    pcloud # pCloud Drive (Electron); unfree
    signal-desktop
    vesktop # Discord
    # zen-browser moved to home-manager (home/zen.nix, programs.zen-browser)
    mpv
    loupe # GNOME image viewer
    nomacs # RAW-capable viewer; default for CR2/CR3 (home/programs.nix)
    nautilus
    gnome-disk-utility
    pavucontrol
    # Can't load session's QT_QPA_PLATFORMTHEME=kde → stock white; use qt6ct (noctalia palette).
    (symlinkJoin {
      name = "qbittorrent-qt6ct";
      paths = [ qbittorrent ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/qbittorrent \
          --set QT_QPA_PLATFORMTHEME qt6ct \
          --prefix QT_PLUGIN_PATH : ${qt6Packages.qt6ct}/lib/qt-6/plugins
      '';
    })
    matugen # material color generation from wallpaper
    firefox

    # ── Media ────────────────────────────────────────────────────────────────
    spotify # was spotify-launcher (AUR downloader wrapper)
    # "gray screen" = its gpuRasterization flag crashing the GPU process on Wayland.
    # Localhost DevTools port lets tidal-live-theme (home/theming.nix) recolor it live.
    (symlinkJoin {
      name = "tidal-hifi-devtools";
      paths = [ tidal-hifi ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = "wrapProgram $out/bin/tidal-hifi --add-flags '--remote-debugging-port=9233 --remote-debugging-address=127.0.0.1'";
    })
    cider-2 # Apple Music (cider.sh 4.x); plain `cider` is the dead 1.x fork

    # ── Gaming / Streaming ────────────────────────────────────────────────────
    # obs-studio and plugins managed via programs.obs-studio in home/default.nix
    protonplus
    # millennium: via its own flake, wired as the Steam package in features/gaming.nix

    # ── Peripherals ───────────────────────────────────────────────────────────
    zmk-studio # runtime keymap editor for the Lily58 (firmware built in ~/Projects/zmk-config)

    # ── Networking ────────────────────────────────────────────────────────────
    # mullvad-vpn comes from the services.mullvad-vpn module (keeps daemon + GUI
    # matched); pkgs.mullvad (headless) lags and would shadow the CLI — keep out.

    # ── Misc ─────────────────────────────────────────────────────────────────
    # ollama managed via services.ollama in services.nix
    # pipewire / wireplumber managed via services.pipewire in audio.nix
    # gamemode managed via programs.gamemode in services.nix
    # keyd managed via services.keyd in services.nix

    pywalfox-native # native messaging host for the Pywalfox browser extension
  ];
}
