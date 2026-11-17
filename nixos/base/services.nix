# Background services every host gets: keyboard remaps, Bluetooth, printer,
# SSH. The VM switches the hardware ones off (nixos/hosts/vm).
{ pkgs, lib, ... }:

let
  # Super+Z/X/C/V = undo, cut, copy, paste.
  meta = {
    z = "C-z";
    x = "S-delete";
    c = "C-insert";
    v = "S-insert";
  };
in
{
  # --- Bluetooth ---
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  # USB power saving on the Bluetooth chip makes keyboards drop and reconnect.
  boot.extraModprobeConfig = "options btusb enable_autosuspend=0";

  # --- Key remapping (keyd) ---
  # The Super+Z/X/C/V keys work in every app, so the desktop must never
  # bind Super with those letters.
  services.keyd = {
    enable = true;
    keyboards = {
      # Caps Lock = push-to-talk (sends Numpad 0).
      default = {
        ids = [ "*" ]; # every keyboard not listed below
        settings = {
          main.capslock = "kp0";
          inherit meta;
        };
      };
      # QK75: the same, plus knob press = Numpad 3 (Discord mute).
      qk75 = {
        ids = [
          "k:0c45:8017"
          "k:05ac:024f"
        ];
        settings = {
          main = {
            capslock = "kp0";
            mute = "kp3";
          };
          inherit meta;
        };
      };
    };
  };
  environment.systemPackages = [ pkgs.keyd ]; # for `sudo keyd monitor`

  # --- Monitor control ---
  # Lets ddcutil talk to the monitors without sudo.
  hardware.i2c.enable = true;

  # --- GameMode ---
  programs.gamemode.enable = true;

  # --- SSH ---
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # --- File search (locate) ---
  services.locate = {
    enable = true;
    package = pkgs.plocate;
    interval = "daily"; # results can be a day behind
  };

  # --- Power profiles ---
  services.power-profiles-daemon.enable = true;

  # --- Nautilus extras ---
  services.gvfs.enable = true; # browse network shares
  services.gnome.sushi.enable = true; # Space previews a file

  # --- Printing ---
  # Brother HL-L2340D on the network, no Brother driver needed.
  services.printing.enable = true;
  # Printer setup fails while it's asleep; don't let that stop printing at boot.
  systemd.services.cups.postStart = lib.mkBefore "set +e";
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

  # --- Firmware updates ---
  # fwupdmgr get-updates && fwupdmgr update
  services.fwupd.enable = true;
}
