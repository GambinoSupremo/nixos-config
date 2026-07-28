# Hardware and misc system services shared by all hosts. The VM host
# force-disables the physical-hardware ones (nixos/hosts/vm).
{ config, pkgs, ... }:

{
  # ── Bluetooth ─────────────────────────────────────────────────────────────────
  # Overridden to false in nixos/hosts/vm/configuration.nix; enable on physical machine.
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
        # Modifier combos must live in a layer named after the modifier —
        # [main] can't bind "super+c". Unlisted keys fall through with Super held.
        meta = {
          c = "C-insert";
          v = "S-insert";
        };
      };
    };
  };

  # ── OpenRazer ─────────────────────────────────────────────────────────────────
  # Overridden to false in nixos/hosts/vm/configuration.nix; enable on physical machine.
  hardware.openrazer = {
    enable = true;
    users  = [ "gav" ];
  };

  # ── GameMode ──────────────────────────────────────────────────────────────────
  # Overridden to false in nixos/hosts/vm/configuration.nix; enable on physical machine.
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

  # ── Power profiles daemon ─────────────────────────────────────────────────────
  services.power-profiles-daemon.enable = true;

  # ── NTP ───────────────────────────────────────────────────────────────────────
  # systemd-timesyncd is lighter than ntpd and sufficient for a desktop.
  services.timesyncd.enable = true;

  # ── gvfs (SMB / network browsing) ────────────────────────────────────────────
  # Needed for Nautilus to browse SMB shares (replaces gvfs-smb).
  services.gvfs.enable = true;

  # ── Flatpak ───────────────────────────────────────────────────────────────────
  # Escape hatch for apps not in nixpkgs; currently nothing installed.
  # First use: flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  services.flatpak.enable = true;

  # ── Firmware updates ──────────────────────────────────────────────────────────
  # SSD/BIOS/peripheral firmware via LVFS: fwupdmgr get-updates && fwupdmgr update
  services.fwupd.enable = true;

  # ── D-Bus ─────────────────────────────────────────────────────────────────────
  services.dbus.enable = true;
}
