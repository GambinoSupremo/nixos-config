# Hardware and misc system services shared by all hosts. The VM host
# force-disables the physical-hardware ones (nixos/hosts/vm).
{ pkgs, ... }:

let
  # Modifier combos must live in a layer named after the modifier:
  # [main] can't bind "super+c". Unlisted keys fall through with Super held.
  meta = {
    z = "C-z";
    x = "S-delete";
    c = "C-insert";
    v = "S-insert";
  };
in
{
  # ── Bluetooth ─────────────────────────────────────────────────────────────────
  # Overridden to false in nixos/hosts/vm/configuration.nix; enable on physical machine.
  hardware.bluetooth.enable = true;
  services.blueman.enable = true; # system tray + pairing GUI

  # ── Key remapping ─────────────────────────────────────────────────────────────
  # keyd — Mac-style edit keys in every app and terminal: Super+Z/X/C/V →
  # undo, cut, copy, paste. Applies with Shift/Ctrl/Alt held too, so compositors
  # must never bind Super with these letters.
  services.keyd = {
    enable = true;
    keyboards = {
      # Caps Lock = push-to-talk. Sends Numpad 0 so game binds and the Hyprland
      # vesktop-mic bind (code:90) keep working.
      default = {
        ids = [ "*" ]; # devices listed below get their own config instead
        settings = {
          main.capslock = "kp0";
          inherit meta;
        };
      };
      # QK75 (wired, 2.4G): same as default, plus knob press = Numpad 3 (Discord mute).
      # Stock SONiX firmware has no VIA, so the remap lives here.
      qk75 = {
        ids = [ "k:0c45:8017" "k:05ac:024f" ];
        settings = {
          main = {
            capslock = "kp0";
            mute = "kp3";
          };
          inherit meta;
        };
      };
      # Basilisk's keyboard keys (clutch, front side button, edge, tilt, top button)
      # switched off so it only uses the buttons the Vaxee NP-01 Ergo has.
      basilisk = {
        ids = [ "k:1532:00e3" ];
        settings.main = {
          kp0 = "noop";
          kp1 = "noop";
          kp2 = "noop";
          kp3 = "noop";
          left = "noop";
          right = "noop";
        };
      };
    };
  };
  environment.systemPackages = [ pkgs.keyd ]; # `sudo keyd monitor`

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

  # ── Printing ──────────────────────────────────────────────────────────────────
  # Brother HL-L2340D at its reserved IP; driverless IPP Everywhere, no Brother driver.
  services.printing.enable = true;
  hardware.printers = {
    ensurePrinters = [
      {
        name = "Brother";
        description = "Brother HL-L2340D";
        deviceUri = "ipp://10.0.0.63/ipp/print";
        model = "everywhere";
        ppdOptions.PageSize = "Letter";
      }
    ];
    ensureDefaultPrinter = "Brother";
  };

  # ── Firmware updates ──────────────────────────────────────────────────────────
  # SSD/BIOS/peripheral firmware via LVFS: fwupdmgr get-updates && fwupdmgr update
  services.fwupd.enable = true;
}
