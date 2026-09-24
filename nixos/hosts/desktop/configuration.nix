{ config, pkgs, lib, inputs, ... }:

let
  qylockThemes = inputs.qylock.legacyPackages.${pkgs.stdenv.hostPlatform.system}.mkSddmThemes { };
  loginGifTheme = pkgs.runCommand "sddm-theme-last-of-us-gif" { } ''
    d=$out/share/sddm/themes/last-of-us-gif
    mkdir -p $(dirname $d)
    cp -r ${qylockThemes}/share/sddm/themes/last-of-us $d
    chmod -R u+w $d
    rm -f $d/bg.mp4
    cp ${../../assets/login-city.gif} $d/bg.gif
    sed -i \
      -e 's|MediaPlayer {[^}]*}|AnimatedImage { id: bgVideo; source: "bg.gif"; anchors.fill: parent; fillMode: Image.PreserveAspectCrop; z: -1000; playing: true; cache: true }|' \
      -e '/VideoOutput {/d' \
      $d/Main.qml
    sed -i 's|^Name=.*|Name=last-of-us-gif|' $d/theme.conf
    grep -q AnimatedImage $d/Main.qml
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

  # last-of-us with the h264 bg.mp4 swapped for a GIF: the greeter's VA-API decode
  # of the video fails on NVIDIA+Wayland and the login screen froze on first boot.
  services.displayManager.sddm.theme = lib.mkForce "last-of-us-gif";
  services.displayManager.sddm.extraPackages = [ loginGifTheme ];
  environment.systemPackages = [ loginGifTheme ];

  # SDDM's Wayland greeter runs its own KWin instance as the `sddm` system
  # user — a separate $HOME from ours, so it never saw our Hyprland/Niri
  # monitor layout and was putting the Philips secondary at the origin as
  # if it were primary. KWin persists output layout at
  # ~/.local/share/kscreen/<hash>.json (hash is derived from the connected
  # outputs' identity, not the user — same filename as our own kscreen
  # config from the old KDE session, just with corrected pos/priority/scale
  # matching hypr/monitor.lua and niri/outputs.kdl: AW3423DW primary at
  # 0,0, Philips secondary at 3440,0 @ 1.5x scale).
  systemd.tmpfiles.rules = [
    "d /var/lib/sddm/.local/share/kscreen 0755 sddm sddm - -"
    "C /var/lib/sddm/.local/share/kscreen/36aeefcbda87d1f6e851bd4d97887c38 0644 sddm sddm - ${./sddm-kscreen.json}"
  ];

  networking.hostName = "gavos";

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
