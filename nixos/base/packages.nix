# System-wide packages. Anything managed by a NixOS module or a
# home-manager programs.* block is deliberately absent — the section
# comments below say where each of those lives.
{ config, pkgs, inputs, lib, ... }:

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

    # ── Editors ───────────────────────────────────────────────────────────────
    neovim         # also configured in home/default.nix
    vim
    nano
    meld
    zed-editor     # was `zed`

    # ── Dev tools ─────────────────────────────────────────────────────────────
    git
    github-cli
    claude-code
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
    # kvantum (kdePackages.qtstyleplugin-kvantum) intentionally NOT installed
    # system-wide: Plasma 6.7's Kirigami detects kvantum presence and imports
    # it as a QML module; when its QML plugin isn't on the KDE session's
    # QML2_IMPORT_PATH the import fails and plasmashell black-screens. KDE uses
    # Breeze by default (correct). If you want kvantum in non-KDE compositors,
    # install it per-user and set QT_STYLE_OVERRIDE in the compositor env
    # file. Re-test after each Plasma major bump (see home/theming.nix).

    # ── Applications ─────────────────────────────────────────────────────────
    obsidian
    signal-desktop
    vesktop                      # Discord
    element-desktop
    # zen-browser moved to home-manager (home/zen.nix, programs.zen-browser)
    mpv
    vlc                          # was vlc-plugins-all (plugins included)
    loupe                        # GNOME image viewer
    nomacs                       # Qt image viewer with RAW support (libraw) —
                                 # default handler for Canon CR2/CR3 (home/programs.nix)
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
    sone                         # native Tidal client, hi-res FLAC up to 24/192
                                 # (was the Flathub flatpak; now in nixpkgs)
    tidal-hifi                   # Tidal Electron client. The 2026-07 "gray screen"
                                 # was NOT upstream (issue #958 is a red herring):
                                 # the app's own gpuRasterization flag crashes the
                                 # GPU process (zygote SIGTRAP) on NVIDIA+Wayland.
                                 # Fix lives in ~/.config/tidal-hifi/config.json:
                                 # flags.gpuRasterization = false. Don't re-enable
                                 # it from the in-app settings menu.
    # cider                      # NOT in nixpkgs — Apple Music client

    # ── Gaming / Streaming ────────────────────────────────────────────────────
    # obs-studio and plugins managed via programs.obs-studio in home/default.nix
    protonplus
    # millennium                 # NOT in nixpkgs — Steam Millennium patcher
    # moondeckbuddy              # NOT in nixpkgs — MoonDeck companion app

    # ── Peripherals ───────────────────────────────────────────────────────────
    polychromatic    # Razer lighting GUI; openrazer daemon via hardware.openrazer in services.nix

    # ── Networking ────────────────────────────────────────────────────────────
    # mullvad-vpn provides CLI + GUI + daemon. services.mullvad-vpn (networking.nix)
    # also sets package = pkgs.mullvad-vpn so daemon and GUI versions always match.
    # pkgs.mullvad (headless-only) is intentionally absent — it lags behind mullvad-vpn
    # and would put a stale CLI binary in PATH alongside the one from mullvad-vpn.
    mullvad-vpn

    # ── Misc ─────────────────────────────────────────────────────────────────
    # ollama managed via services.ollama in services.nix
    # profile-sync-daemon managed via services.psd in services.nix
    # pipewire / wireplumber managed via services.pipewire in audio.nix
    # gamemode managed via programs.gamemode in services.nix
    # keyd managed via services.keyd in services.nix

    pywalfox-native              # native messaging host for the Pywalfox browser extension
  ];
}
