{ pkgs, inputs, ... }:

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

  # Newest plain kernel: zen 7.3.4 panicked at boot (2026-11-13); CachyOS tuning
  # stays in features/tuning.nix. Fallback if this fails: pin zen 7.2.15 (git log).
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Suspend: mouse receivers woke the PC within seconds, then the re-suspend hung.
  # Only the power button wakes it now (Razer Naga, VAXEE, Steam puck).
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="1532", ATTR{idProduct}=="00b4", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="3057", ATTR{idProduct}=="2002", ATTR{power/wakeup}="disabled"
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="28de", ATTR{idProduct}=="1304", ATTR{power/wakeup}="disabled"
  '';

  # ── Quiet, pretty boot ────────────────────────────────────────────────────────
  # Limine: boot menu with a random theme wallpaper each boot (2026-11-13). Was
  # systemd-boot; its files stay on the ESP as an F12 fallback. Themed GRUB was
  # too slow (2026-07-09).
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.limine = {
    enable = true;
    # ESP is 1 GiB and still holds systemd-boot's copies; ~90 MB per kernel+initrd.
    maxGenerations = 10;
    enableEditor = false;
    # Memtest86+ entry (RAM stability checks after BIOS changes).
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
      # Neutral colours: the wallpaper rotates, so nothing theme-specific.
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
