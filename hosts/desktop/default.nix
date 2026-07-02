{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/hardware/nvidia.nix
    ../../modules/core.nix
    ../../modules/users.nix
    ../../modules/networking.nix
    ../../modules/desktop.nix
    ../../modules/audio.nix
    ../../modules/services.nix
    ../../modules/packages.nix
    ../../modules/gaming.nix
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
  # GNOME Keyring (enabled in modules/desktop.nix) handles SecretService D-Bus
  # for Niri/Mango/Hyprland — and KDE works fine with it too. KWallet can still
  # be opened manually inside KDE if ever needed.
  security.pam.services.login.kwallet.enable  = lib.mkForce false;
  security.pam.services.sddm.kwallet.enable   = lib.mkForce false;

  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # systemd initrd: faster boot, cleaner Plymouth, better error reporting.
  # Safe on this hardware — the AW3423DW scanout fix is in the driver, not initrd.
  boot.initrd.systemd.enable = true;

  # ── Btrfs snapshots ───────────────────────────────────────────────────────────
  # Root snapshot lets you roll back a broken nixos-rebuild without needing to
  # boot into an old generation. Home snapshot covers user data separately.
  services.snapper.configs = {
    root = {
      SUBVOLUME        = "/";
      ALLOW_USERS      = [ "gav" ];
      TIMELINE_CREATE  = true;
      TIMELINE_CLEANUP = true;
    };
    home = {
      SUBVOLUME        = "/home";
      ALLOW_USERS      = [ "gav" ];
      TIMELINE_CREATE  = true;
      TIMELINE_CLEANUP = true;
    };
  };

  # ── Profile Sync Daemon ───────────────────────────────────────────────────────
  # Moves Zen Browser profile to tmpfs for faster page loads and less SSD wear.
  # Desktop-only — the VM has no persistent browser sessions.
  services.psd.enable = true;

  environment.systemPackages = with pkgs; [
    btrfs-assistant
    snapper
  ];

}
