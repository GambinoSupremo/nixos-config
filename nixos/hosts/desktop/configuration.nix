{ config, pkgs, lib, inputs, ... }:

{
  # Import order is load-bearing: list options merge in order, so reordering
  # changes the system hash even with nothing functional changed.
  imports = [
    ./hardware-configuration.nix
    ../../features/nvidia.nix
    ../../base/core.nix
    ../../base/users.nix
    ../../base/networking.nix
    ../../features/desktop.nix
    ../../base/audio.nix
    ../../base/services.nix
    ../../base/packages.nix
    ../../features/gaming.nix
    ../../features/sunshine.nix
    inputs.qylock.nixosModules.default
  ];

  # Latest mainline kernel, desktop only. The kernel was exonerated as the
  # AW3423DW scanout regressor (that was the NVIDIA driver branch, now on 610).
  boot.kernelPackages = pkgs.linuxPackages_latest;

  programs.qylock = {
    enable = true;
    theme  = "last-of-us";
    quickshell.enable = false;  # SDDM login theme only — Noctalia still owns the in-session lock
  };

  networking.hostName = "gavos";

  # KDE Plasma 6 — available as a session in SDDM alongside MangoWM/Niri/Hyprland.
  services.desktopManager.plasma6.enable = true;
  services.xserver.enable = true;
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    # Already-excluded bloat
    plasma-browser-integration
    oxygen
    elisa
    kmail
    kontact
    korganizer
    # Apps replaced by better alternatives
    dolphin        # file manager — use terminal or another
    konsole        # terminal — using ghostty
    kate           # text editor — using whatever's in dotfiles
    gwenview       # image viewer — using mpv or cli
    okular         # document viewer
    ark            # archive manager
    dragon         # video player — using mpv
    kcalc          # calculator
    kfind          # file search
    # KDE-specific infrastructure we don't want
    kwalletmanager # KWallet GUI — KWallet disabled via PAM anyway
    plasma-welcome # first-run tour screen
    discover       # software center — using nix
    print-manager  # printing
  ];

  # KWallet PAM auto-start off — GNOME Keyring handles SecretService for every
  # session (KDE included); KWallet can still be opened manually.
  security.pam.services.login.kwallet.enable  = lib.mkForce false;
  security.pam.services.sddm.kwallet.enable   = lib.mkForce false;

  # systemd-boot: plain but instant. (Tried themed GRUB 2026-07-09, reverted —
  # the menu load lag wasn't worth cosmetics on a menu that's hidden anyway.)
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # systemd initrd: faster boot, cleaner Plymouth, better error reporting.
  boot.initrd.systemd.enable = true;

  # ── Quiet, pretty boot ────────────────────────────────────────────────────────
  # 5s generation menu at boot — roll back without holding a key (0 = straight through).
  boot.loader.timeout = 5;
  boot.loader.systemd-boot.configurationLimit = 10;

  # Plymouth theme from the adi1090x pack — swap the name in BOTH places to try
  # another. Esc during boot drops to the text log.
  boot.plymouth = {
    enable = true;
    theme  = "rings";
    themePackages = [
      (pkgs.adi1090x-plymouth-themes.override { selected_themes = [ "rings" ]; })
    ];
  };

  # Silence the console text Plymouth would otherwise paint over.
  boot.consoleLogLevel = 3;
  boot.initrd.verbose  = false;
  boot.kernelParams = [
    "quiet"
    "udev.log_priority=3"
  ];

  # ── Profile Sync Daemon ───────────────────────────────────────────────────────
  # Zen profile in tmpfs: faster page loads, less SSD wear. Desktop only.
  services.psd.enable = true;

  # No btrfs-assistant: it drags snapper back into the closure (removed
  # 2026-07-14) and plain `btrfs` subcommands cover what it wrapped.
}
