# Hardware and misc system services shared by all hosts. The VM host
# force-disables the physical-hardware ones (nixos/hosts/vm).
{ pkgs, ... }:

{
  # ── Bluetooth ─────────────────────────────────────────────────────────────────
  # Overridden to false in nixos/hosts/vm/configuration.nix; enable on physical machine.
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true; # system tray + pairing GUI

  # ── Key remapping ─────────────────────────────────────────────────────────────
  # keyd — Mac-style edit keys in every app and terminal: Super+Z/X/C/V →
  # undo, cut, copy, paste. Applies with Shift/Ctrl/Alt held too, so compositors
  # must never bind Super with these letters.
  services.keyd = {
    enable = true;
    keyboards.default = {
      ids = [ "*" ];
      settings = {
        # Modifier combos must live in a layer named after the modifier —
        # [main] can't bind "super+c". Unlisted keys fall through with Super held.
        meta = {
          z = "C-z";
          x = "S-delete";
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
    users = [ "gav" ];
  };

  # ── GameMode ──────────────────────────────────────────────────────────────────
  # Overridden to false in nixos/hosts/vm/configuration.nix; enable on physical machine.
  programs.gamemode.enable = true;

  # ── SSH ───────────────────────────────────────────────────────────────────────
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # ── locate / plocate ──────────────────────────────────────────────────────────
  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "hourly";
  };

  # ── Power profiles daemon ─────────────────────────────────────────────────────
  services.power-profiles-daemon.enable = true;

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
