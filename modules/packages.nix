{ config, pkgs, inputs, lib, ... }:

let
  # zen-browser is not in nixpkgs; pull from the flake input declared in flake.nix
  zen = inputs.zen-browser.packages.${pkgs.system}.default;
in
{
  environment.systemPackages = with pkgs; [

    # ── Shell / Terminal ──────────────────────────────────────────────────────
    # fish registered system-wide via programs.fish in users.nix
    ghostty
    kitty
    starship
    tmux
    bat
    eza
    fzf
    zoxide
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
    lsd           # explicitly installed on CachyOS alongside eza

    # ── Editors ───────────────────────────────────────────────────────────────
    neovim         # also configured in home/default.nix
    vim
    nano
    meld
    zed-editor     # was `zed`

    # ── Dev tools ─────────────────────────────────────────────────────────────
    git
    github-cli
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
    usbutils          # usbutils
    hwinfo
    # pkgfile / rebuild-detector / reflector — Arch-specific, not needed
    # cachy-update / chwd / cachyos-* — CachyOS-specific, not needed

    # ── Wayland tooling ───────────────────────────────────────────────────────
    # niri registered via programs.niri in desktop.nix
    cliphist
    grim
    slurp
    wl-clipboard
    wtype
    wev
    playerctl
    fuzzel
    xwayland-satellite  # rootless Xwayland for pure-Wayland compositors
    xorg.xrandr
    wayland-protocols
    uwsm                # Wayland session manager (also used by niri session)
    # mangowm       — provided via inputs.mangowm.nixosModules.mango in desktop.nix
    # noctalia-shell — provided via inputs.noctalia.homeModules.default in home/default.nix
    #                  (also available as pkgs.noctalia-shell in nixpkgs-unstable)
    # scenefx        — wlroots-effects; likely bundled in MangoWM's flake output

    # ── Themes / Appearance ───────────────────────────────────────────────────
    nwg-look
    bibata-cursors               # was bibata-cursor-theme-bin (AUR)
    papirus-icon-theme
    tela-icon-theme
    # nordzy-icon-theme          # NOT in nixpkgs (AUR only)
    adw-gtk3                     # was adw-gtk-theme
    kdePackages.qtstyleplugin-kvantum  # Qt6 Kvantum style plugin
    libsForQt5.qtstyleplugin-kvantum   # Qt5 Kvantum style plugin (was kvantum)
    qt6ct
    libsForQt5.qt5ct             # was qt5ct-kde (AUR; verify nixpkgs name)
    kdePackages.breeze           # was breeze

    # ── Applications ─────────────────────────────────────────────────────────
    obsidian
    signal-desktop
    vesktop                      # Discord
    element-desktop
    vivaldi
    zen                          # zen-browser from flake input
    mpv
    vlc                          # was vlc-plugins-all (plugins included)
    loupe                        # GNOME image viewer
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
    tidal-hifi                   # was tidal-hifi-tidaluna; tidaluna variant NOT in nixpkgs
    # cider                      # NOT in nixpkgs — Apple Music client

    # ── Gaming / Streaming ────────────────────────────────────────────────────
    obs-studio
    # obs-studio plugins are better managed via home-manager:
    #   programs.obs-studio.plugins = with pkgs.obs-studio-plugins; [ obs-vaapi obs-vkcapture ];
    protonplus
    # millennium                 # NOT in nixpkgs — Steam Millennium patcher
    # moondeckbuddy              # NOT in nixpkgs — MoonDeck companion app

    # ── Peripherals ───────────────────────────────────────────────────────────
    polychromatic    # Razer lighting GUI; openrazer daemon via hardware.openrazer in services.nix

    # ── Networking ────────────────────────────────────────────────────────────
    # mullvad-vpn daemon managed via services.mullvad-vpn in networking.nix
    # CLI tools still useful to have in PATH:
    mullvad           # mullvad CLI

    # ── Misc ─────────────────────────────────────────────────────────────────
    # ollama managed via services.ollama in services.nix
    # profile-sync-daemon managed via services.psd in services.nix
    # pipewire / wireplumber managed via services.pipewire in audio.nix
    # gamemode managed via programs.gamemode in services.nix
    # keyd managed via services.keyd in services.nix

    # python-pywalfox            # AUR only — pywalfox Firefox theme sync
  ];
}
