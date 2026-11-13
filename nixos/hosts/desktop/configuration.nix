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
  # Limine: themed boot menu (2026-11-13; was systemd-boot, whose files stay on
  # the ESP as an F12 fallback). Themed GRUB was too slow (2026-07-09).
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
      wallpapers = [ (pkgs.callPackage ./limine-wallpaper.nix { inherit inputs; }) ];
      wallpaperStyle = "stretched";
      interface = {
        branding = "gavos";
        brandingColor = "a48cf2";
        helpColor = "04d1f9";
        helpColorBright = "37f499";
      };
      # Eldritch palette, to match the island wallpaper.
      graphicalTerminal = {
        font.scale = "2x2";
        background = "70212337";
        foreground = "ebfafa";
        brightForeground = "ffffff";
        palette = "212337;f16c75;37f499;f1fc79;04d1f9;a48cf2;04d1f9;ebfafa";
        brightPalette = "7081d0;f0313e;10a56f;f1fc79;10b8f7;a48cf2;04d1f9;ffffff";
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
