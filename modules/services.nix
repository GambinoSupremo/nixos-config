{ config, pkgs, ... }:

{
  # ── Bluetooth ─────────────────────────────────────────────────────────────────
  # Overridden to false in hosts/vm/default.nix; enable on physical machine.
  hardware.bluetooth = {
    enable      = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;   # system tray + pairing GUI

  # ── Key remapping ─────────────────────────────────────────────────────────────
  # keyd — kernel-level remapping. Super+C/V → Ctrl+Insert / Shift+Insert
  # so universal clipboard shortcuts work across all apps including terminals.
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids      = [ "*" ];
      settings = {
        main = {
          "super+c" = "C-insert";
          "super+v" = "S-insert";
        };
      };
    };
  };

  # ── OpenRazer ─────────────────────────────────────────────────────────────────
  # Overridden to false in hosts/vm/default.nix; enable on physical machine.
  hardware.openrazer = {
    enable = true;
    users  = [ "gav" ];
  };

  # ── GameMode ──────────────────────────────────────────────────────────────────
  # Overridden to false in hosts/vm/default.nix; enable on physical machine.
  programs.gamemode.enable = true;

  # ── SSH ───────────────────────────────────────────────────────────────────────
  services.openssh = {
    enable   = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin        = "no";
    };
  };

  # ── locate / plocate ──────────────────────────────────────────────────────────
  services.locate = {
    enable   = true;
    package  = pkgs.plocate;
    interval = "hourly";
  };

  # ── Profile Sync Daemon ───────────────────────────────────────────────────────
  # Moves browser profiles to tmpfs for speed and SSD longevity.
  # Verify this option path against your nixpkgs revision if it errors.
  # services.psd.enable = true;  # verify module exists

  # ── Power profiles daemon ─────────────────────────────────────────────────────
  services.power-profiles-daemon.enable = true;

  # ── NTP ───────────────────────────────────────────────────────────────────────
  # systemd-timesyncd is lighter than ntpd and sufficient for a desktop.
  services.timesyncd.enable = true;

  # ── gvfs (SMB / network browsing) ────────────────────────────────────────────
  # Needed for Nautilus to browse SMB shares (replaces gvfs-smb).
  services.gvfs.enable = true;

  # ── D-Bus ─────────────────────────────────────────────────────────────────────
  services.dbus.enable = true;

  # ── Snapper ───────────────────────────────────────────────────────────────────
  # Only relevant if this VM uses btrfs. Configure per your filesystem setup.
  # services.snapper.configs.root = {
  #   SUBVOLUME        = "/";
  #   ALLOW_USERS      = [ "gav" ];
  #   TIMELINE_CREATE  = true;
  #   TIMELINE_CLEANUP = true;
  # };
}
