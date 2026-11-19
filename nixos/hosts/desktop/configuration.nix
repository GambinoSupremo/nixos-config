# My desktop PC (gavos): kernel, boot menu, boot splash and suspend fixes.
{ pkgs, inputs, ... }:

{
  # Keep this order; changing it rebuilds the system for no reason.
  imports = [
    ./hardware-configuration.nix
    ../../features/amd.nix
    ../../base
    ../../features/gaming.nix
    ../../features/local-ai.nix
    ../../features/sunshine.nix
    ../../features/tuning.nix
    ../../features/yubikey.nix
  ];

  # --- Disk ---
  # Monthly check of the disk for silent corruption.
  services.btrfs.autoScrub = {
    enable = true;
    interval = "monthly";
    fileSystems = [ "/" ];
  };

  # --- Kernel ---
  # Newest plain kernel. Not zen: 7.3.4 crashed at boot.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # --- Suspend ---
  # The mouse receivers and Steam puck woke the PC seconds after suspend.
  # Only the power button wakes it now.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="00b4", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="3057", ATTR{idProduct}=="2002", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1304", ATTR{power/wakeup}="disabled"
  '';

  # --- Boot menu (Limine) ---
  # Shows a random theme wallpaper each boot. The old systemd-boot files are
  # still on the boot partition as an F12 fallback.
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.limine = {
    enable = true;
    # The boot partition is 1 GiB and each entry takes about 90 MB.
    maxGenerations = 10;
    enableEditor = false;
    # Memtest86+ entry, for checking RAM after BIOS changes.
    additionalFiles."efi/memtest86/memtest86.efi" = "${pkgs.memtest86plus}/mt86plus.efi";
    extraEntries = ''
      /Memtest86+
        protocol: efi
        path: boot():///efi/memtest86/memtest86.efi
    '';
    style = {
      wallpapers = pkgs.callPackage ./limine-wallpaper.nix { inherit inputs; };
      wallpaperStyle = "stretched";
      interface = {
        branding = "gavos";
        brandingColor = "ffffff";
        helpColor = "c0c4d6";
        helpColorBright = "ffffff";
      };
      # Neutral colors, since the wallpaper changes every boot.
      graphicalTerminal = {
        font.scale = "2x2";
        background = "60101014";
        foreground = "e6e6ea";
        brightForeground = "ffffff";
        palette = "101014;e06c75;98c379;e5c07b;8fa3c8;b39ddb;88c0d0;e6e6ea";
        brightPalette = "5c6370;ef8a92;b5e09a;f0d494;aec3e8;cdb8f0;a8d8e6;ffffff";
        margin = 96;
        marginGradient = 0;
      };
    };
  };

  # --- Boot splash (Plymouth) ---
  # The "gavos" logo from plymouth-gavos.nix. Esc during boot shows the text log.
  boot.plymouth = {
    enable = true;
    theme = "gavos";
    themePackages = [ (pkgs.callPackage ./plymouth-gavos.nix { }) ];
  };

  # Hides the boot text the splash would otherwise cover.
  boot.consoleLogLevel = 3;
  boot.kernelParams = [
    "quiet"
    "udev.log_priority=3"
  ];

  # No btrfs-assistant: it pulls snapper back in.
}
