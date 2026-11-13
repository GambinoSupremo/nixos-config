{ pkgs, ... }:

{
  # Import order is load-bearing: list options merge in order, so reordering
  # changes the system hash even with nothing functional changed.
  imports = [
    ./hardware-configuration.nix
    ../../features/amd.nix
    ../../base
    ../../features/gaming.nix
    ../../features/sunshine.nix
    ../../features/tuning.nix
    ../../features/razer-white.nix
  ];

  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # Zen kernel from nixpkgs (desktop-tuned, on cache.nixos.org). CachyOS tuning
  # stays in features/tuning.nix; see docs/decisions.md for why the kernel changed.
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Plex webhooks for the Obsidian watch log (home/plex-log.nix); LAN interface only.
  networking.firewall.interfaces.enp7s0.allowedTCPPorts = [ 8765 ];

  # Suspend: mouse receivers woke the PC within seconds, then the re-suspend hung.
  # Only the power button wakes it now (Razer Naga, VAXEE, Steam puck).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="00b4", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="3057", ATTR{idProduct}=="2002", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1304", ATTR{power/wakeup}="disabled"
  '';

  # systemd-boot: plain but instant. (Tried themed GRUB 2026-07-09, reverted —
  # the menu load lag wasn't worth cosmetics on a menu that's hidden anyway.)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # ── Quiet, pretty boot ────────────────────────────────────────────────────────
  boot.loader.systemd-boot.configurationLimit = 20;
  # Memtest86+ entry in the boot menu (RAM stability checks after BIOS changes).
  boot.loader.systemd-boot.memtest86.enable = true;

  # Boot/shutdown splash: ASCII "gavos" logo (plymouth-gavos.nix). Was adi1090x
  # "rings" until 2026-11-10. Esc during boot drops to the text log.
  boot.plymouth = {
    enable = true;
    theme = "gavos";
    themePackages = [ (pkgs.callPackage ./plymouth-gavos.nix { }) ];
  };

  # Silence the console text Plymouth would otherwise paint over.
  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "quiet"
    "udev.log_priority=3"
  ];

  # No btrfs-assistant: it drags snapper back into the closure (removed
  # 2026-07-14) and plain `btrfs` subcommands cover what it wrapped.
}
