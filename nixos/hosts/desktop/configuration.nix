{
  pkgs,
  lib,
  inputs,
  ...
}:

let
  qylockThemes = inputs.qylock.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mkSddmThemes { };
  # pixel-dusk-city with bg.mp4 transcoded to animated WebP (greeter video decode freezes on NVIDIA).
  loginTheme =
    pkgs.runCommand "sddm-theme-pixel-dusk-city-webp" { nativeBuildInputs = [ pkgs.ffmpeg-headless ]; }
      ''
          d=$out/share/sddm/themes/pixel-dusk-city-webp
          mkdir -p $(dirname $d)
          cp -r ${qylockThemes}/share/sddm/themes/pixel-dusk-city $d
          chmod -R u+w $d
          ffmpeg -v error -i $d/bg.mp4 -an -vf fps=30 -c:v libwebp -q:v 85 -compression_level 4 -loop 0 $d/bg.webp
          rm $d/bg.mp4
          cat > $d/BackgroundVideo.qml <<'QML'
        import QtQuick
        AnimatedImage { anchors.fill: parent; source: "bg.webp"; fillMode: Image.PreserveAspectCrop; smooth: false; playing: true; cache: false }
        QML
          sed -i 's|^Name=.*|Name=pixel-dusk-city-webp|' $d/metadata.desktop
      '';
in
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
    ../../features/cachyos.nix
    inputs.qylock.nixosModules.default
  ];

  # CachyOS kernel (BORE + CachyOS patches), Zen 4 build for the 7800X3D.
  # Pinned overlay = upstream's nixpkgs rev, so it hits their binary cache.
  # Fallback: pkgs.linuxPackages_latest (mainline).
  nixpkgs.overlays = [ inputs.nix-cachyos-kernel.overlays.pinned ];
  boot.kernelPackages = pkgs.cachyosKernels.linuxPackages-cachyos-latest-zen4;

  programs.qylock = {
    enable = true;
    theme = "pixel-dusk-city";
    quickshell.enable = false; # SDDM login theme only — Noctalia still owns the in-session lock
  };

  services.displayManager.sddm.theme = lib.mkForce "pixel-dusk-city-webp";
  # qtimageformats provides the WebP decoder for the animated background.
  services.displayManager.sddm.extraPackages = [
    loginTheme
    pkgs.qt6.qtimageformats
  ];
  environment.systemPackages = [ loginTheme ];

  # SDDM's Wayland greeter runs KWin as the `sddm` user, which never saw our
  # layout; L+ re-links KWin 6's output config each boot (C/C+ never overwrite).
  systemd.tmpfiles.rules = [
    "d /var/lib/sddm/.config 0755 sddm sddm - -"
    "L+ /var/lib/sddm/.config/kwinoutputconfig.json - - - - ${./sddm-kwinoutputconfig.json}"
  ];

  networking.hostName = "gavos";

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
