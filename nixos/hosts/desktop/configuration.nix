{ config, pkgs, lib, inputs, ... }:

{
  # NOTE: import order is load-bearing — NixOS merges list options
  # (systemPackages etc.) in import order, so reordering changes the built
  # system hash even when nothing functional changes.
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
    inputs.silentSDDM.nixosModules.default
  ];

  # Kernel: latest mainline (currently 7.x) from nixpkgs — fully cached, no
  # third-party flake. Desktop only; the VM keeps the conservative default.
  # The kernel was exonerated as the AW3423DW scanout regressor (that's the
  # NVIDIA driver branch — now on 610), so running mainline 7.x here is fine.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  programs.silentSDDM = {
    enable = true;
    theme  = "default";
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

  # KWallet: disable PAM auto-start so it doesn't open in non-KDE sessions.
  # GNOME Keyring (enabled in nixos/features/desktop.nix) handles SecretService D-Bus
  # for Niri/Mango/Hyprland — and KDE works fine with it too. KWallet can still
  # be opened manually inside KDE if ever needed.
  security.pam.services.login.kwallet.enable  = lib.mkForce false;
  security.pam.services.sddm.kwallet.enable   = lib.mkForce false;

  # systemd-boot: plain but instant. (Tried themed GRUB 2026-07-09, reverted —
  # the menu load lag wasn't worth cosmetics on a menu that's hidden anyway.)
  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # systemd initrd: faster boot, cleaner Plymouth, better error reporting.
  # Safe on this hardware — the AW3423DW scanout fix is in the driver, not initrd.
  boot.initrd.systemd.enable = true;

  # ── Quiet, pretty boot ────────────────────────────────────────────────────────
  # Show the generation menu for 5s at boot. Each entry displays its NixOS
  # version + build date (e.g. "NixOS 26.11.20260702... Generation 79"), so you
  # can see exactly what you're booting and roll back without holding a key.
  # Set back to 0 to boot straight through again.
  boot.loader.timeout = 5;
  boot.loader.systemd-boot.configurationLimit = 10;

  # Plymouth splash covers boot AND shutdown. Theme comes from the adi1090x
  # community pack — swap the name in BOTH places to try another (pack list:
  # https://github.com/adi1090x/plymouth-themes). Press Esc during boot to
  # drop to the full text log if something hangs.
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
  # Moves Zen Browser profile to tmpfs for faster page loads and less SSD wear.
  # Desktop-only — the VM has no persistent browser sessions.
  services.psd.enable = true;

  environment.systemPackages = with pkgs; [
    # btrfs maintenance GUI (scrub, balance, subvolume view). Its snapshot tab
    # is inert — snapper was removed 2026-07-14 (this install never had a
    # working .snapshots subvolume layout).
    btrfs-assistant
  ];

}
