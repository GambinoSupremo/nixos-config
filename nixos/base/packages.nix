# System-wide packages; anything owned by a NixOS module or HM programs.* is
# deliberately absent. git + neovim duplicated on purpose for root/TTY recovery.
{ config, pkgs, inputs, lib, ... }:

{
  environment.systemPackages = with pkgs; [

    # ── Shell / Terminal ──────────────────────────────────────────────────────
    # fish registered system-wide via programs.fish in users.nix
    # starship / bat / fzf / zoxide: HM-owned — home/shell.nix
    ghostty
    kitty
    tmux
    eza          # stays: only aliased (no programs.eza) in home/shell.nix
    ripgrep
    fd
    tree
    duf
    less
    pv
    wget
    curl

    # ── File management ───────────────────────────────────────────────────────
    stow
    rsync
    unrar
    unzip

    # ── Editors ───────────────────────────────────────────────────────────────
    neovim
    vim
    nano
    meld
    zed-editor

    # ── Dev tools ─────────────────────────────────────────────────────────────
    git
    github-cli
    claude-code
    nil            # Nix language server — Zed's Nix extension shells out to it
    jq             # JSON CLI; required by niri
    cmake
    ninja
    python3
    python3Packages.defusedxml
    python3Packages.packaging
    # cli11           # header-only C++ CLI library — add if writing C++ apps
    # gemini-cli      # check nixpkgs — may be `google-gemini-cli` or absent
    # opencode-bin    # NOT in nixpkgs

    # ── System utilities ──────────────────────────────────────────────────────
    btop
    glances
    fastfetch
    dmidecode
    lsscsi
    hdparm
    smartmontools
    sg3_utils
    usbutils
    hwinfo
    # pkgfile / rebuild-detector / reflector — Arch-specific, not needed
    # cachy-update / chwd / cachyos-* — CachyOS-specific, not needed

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
    xwayland-satellite  # rootless Xwayland for pure-Wayland compositors
    xrandr
    wayland-protocols
    uwsm                # Wayland session manager (also used by niri session)
    # mangowm       — provided via inputs.mangowm.nixosModules.mango in desktop.nix
    # noctalia — v5, managed by the upstream HM module (programs.noctalia)
    #            in home/default.nix; runs as noctalia.service
    # scenefx        — wlroots-effects; likely bundled in MangoWM's flake output

    # ── Themes / Appearance ───────────────────────────────────────────────────
    nwg-look
    bibata-cursors               # was bibata-cursor-theme-bin (AUR)
    papirus-icon-theme
    tela-icon-theme
    nordzy-icon-theme            # in nixpkgs (pkgs/by-name) despite old AUR-only note
    adw-gtk3                     # was adw-gtk-theme
    qt6Packages.qt6ct            # top-level qt6ct became a throw alias 2025-10-27
    libsForQt5.qt5ct             # was qt5ct-kde (AUR; verify nixpkgs name)
    kdePackages.breeze           # was breeze
    # kvantum intentionally NOT system-wide: Plasma's Kirigami QML-imports it and
    # black-screens plasmashell. Want it elsewhere? Per-user + QT_STYLE_OVERRIDE.

    # ── Applications ─────────────────────────────────────────────────────────
    obsidian
    signal-desktop
    vesktop                      # Discord
    element-desktop
    # zen-browser moved to home-manager (home/zen.nix, programs.zen-browser)
    mpv
    vlc                          # was vlc-plugins-all (plugins included)
    loupe                        # GNOME image viewer
    nomacs                       # RAW-capable viewer; default for CR2/CR3 (home/programs.nix)
    nautilus
    gnome-disk-utility
    pavucontrol
    qbittorrent
    matugen                      # material color generation from wallpaper

    # lunatask                   # NOT in nixpkgs — closed-source task manager
    # keeper-password-manager    # NOT in nixpkgs — use web vault or Flatpak
    # fluxer-bin                 # NOT in nixpkgs
    # dgop                       # NOT in nixpkgs (unrecognized package)
    # shelly                     # NOT in nixpkgs

    # ── Media ────────────────────────────────────────────────────────────────
    spotify                      # was spotify-launcher (AUR downloader wrapper)
    sone                         # native Tidal client, hi-res FLAC (was flatpak)
    tidal-hifi                   # "gray screen" = its gpuRasterization flag crashing NVIDIA+Wayland
                                 # (not upstream #958); keep it off in config.json AND in-app settings
    # cider                      # NOT in nixpkgs — Apple Music client

    # ── Gaming / Streaming ────────────────────────────────────────────────────
    # obs-studio and plugins managed via programs.obs-studio in home/default.nix
    protonplus
    # millennium: via its own flake, wired as the Steam package in features/gaming.nix
    # moondeckbuddy              # NOT in nixpkgs — MoonDeck companion app

    # ── Peripherals ───────────────────────────────────────────────────────────
    polychromatic    # Razer lighting GUI; openrazer daemon via hardware.openrazer in services.nix
    zmk-studio       # runtime keymap editor for the Lily58 (firmware built in ~/Projects/zmk-config)

    # ── Networking ────────────────────────────────────────────────────────────
    # mullvad-vpn comes from the services.mullvad-vpn module (keeps daemon + GUI
    # matched); pkgs.mullvad (headless) lags and would shadow the CLI — keep out.

    # ── Misc ─────────────────────────────────────────────────────────────────
    # ollama managed via services.ollama in services.nix
    # profile-sync-daemon managed via services.psd in services.nix
    # pipewire / wireplumber managed via services.pipewire in audio.nix
    # gamemode managed via programs.gamemode in services.nix
    # keyd managed via services.keyd in services.nix

    pywalfox-native              # native messaging host for the Pywalfox browser extension
  ];
}
