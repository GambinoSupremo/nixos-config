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

  # Zen kernel from nixpkgs (desktop-tuned, on cache.nixos.org). CachyOS tuning
  # stays in features/tuning.nix; see DECISIONS.md for why the kernel changed.
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Plex webhooks for the Obsidian watch log (home/plex-log.nix); LAN interface only.
  networking.firewall.interfaces.enp7s0.allowedTCPPorts = [ 8765 ];

  # systemd-boot: plain but instant. (Tried themed GRUB 2026-07-09, reverted —
  # the menu load lag wasn't worth cosmetics on a menu that's hidden anyway.)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # systemd initrd: faster boot, cleaner Plymouth, better error reporting.
  boot.initrd.systemd.enable = true;

  # ── Quiet, pretty boot ────────────────────────────────────────────────────────
  # 5s generation menu at boot — roll back without holding a key (0 = straight through).
  boot.loader.timeout = 5;
  boot.loader.systemd-boot.configurationLimit = 20;
  # Memtest86+ entry in the boot menu (RAM stability checks after BIOS changes).
  boot.loader.systemd-boot.memtest86.enable = true;

  # Plymouth theme from the adi1090x pack — swap the name in BOTH places to try
  # another. Esc during boot drops to the text log.
  boot.plymouth = {
    enable = true;
    theme = "rings";
    themePackages = [
      (pkgs.adi1090x-plymouth-themes.override { selected_themes = [ "rings" ]; })
    ];
  };

  # Silence the console text Plymouth would otherwise paint over.
  boot.consoleLogLevel = 3;
  boot.initrd.verbose = false;
  boot.kernelParams = [
    "quiet"
    "udev.log_priority=3"
  ];

  # No btrfs-assistant: it drags snapper back into the closure (removed
  # 2026-07-14) and plain `btrfs` subcommands cover what it wrapped.
}
