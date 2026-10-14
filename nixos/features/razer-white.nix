# Basilisk V4 Pro lighting. Synapse only saves buttons/DPI onboard; without it
# the mouse cycles colours. OpenRazer doesn't know this mouse yet, so
# razer-white sends OpenRazer's static-colour report straight over hidraw.
# The colour sticks across power cycles; rerun it after using Synapse.
{ pkgs, ... }:

let
  razer-white = pkgs.writers.writePython3Bin "razer-white" { } ''
    import fcntl
    import glob
    import os
    import sys
    import time

    MOUSE = "0003:00001532:000000E3"  # Basilisk V4 Pro (HyperSpeed dongle)


    def ioc(nr, size):
        return (3 << 30) | (size << 16) | (ord("H") << 8) | nr  # _IOWR('H')


    def report(cls, cmd, args):
        # 90-byte Razer report, transaction id 0x1f, XOR crc over 2..87
        r = bytearray(90)
        r[1], r[5], r[6], r[7] = 0x1F, len(args), cls, cmd
        r[8:8 + len(args)] = bytes(args)
        for b in r[2:88]:
            r[88] ^= b
        return r


    def send(path, r):
        fd = os.open(path, os.O_RDWR)
        try:
            buf = bytearray(b"\x00" + r)
            fcntl.ioctl(fd, ioc(0x06, len(buf)), buf)  # HIDIOCSFEATURE
            time.sleep(0.05)
            fcntl.ioctl(fd, ioc(0x07, len(buf)), buf)  # HIDIOCGFEATURE
            return buf[1] == 0x02  # status ok
        finally:
            os.close(fd)


    rgb = bytes.fromhex(sys.argv[1] if len(sys.argv) > 1 else "ffffff")
    denied = False
    for node in sorted(glob.glob("/sys/class/hidraw/hidraw*")):
        with open(node + "/device/uevent") as f:
            if "HID_ID=" + MOUSE not in f.read():
                continue
        dev = "/dev/" + os.path.basename(node)
        try:
            # Only the vendor interface takes feature reports; others EPIPE.
            # args: varstore, all LEDs, static, -, -, 1 colour, r, g, b
            if send(dev, report(0x0F, 0x02, [1, 0, 1, 0, 0, 1, *rgb])):
                print("set #" + rgb.hex() + " via " + dev)
                sys.exit(0)
        except PermissionError:
            denied = True
        except OSError:
            pass
    if denied:
        sys.exit("no access to the mouse (udev rule not applied yet? replug)")
    sys.exit("Basilisk V4 Pro not found (dongle plugged in?)")
  '';
in
{
  environment.systemPackages = [ razer-white ];

  # uaccess has to be tagged before 73-seat-late, so not in extraRules (99-local).
  services.udev.packages = [
    (pkgs.writeTextDir "lib/udev/rules.d/70-razer-white.rules" ''
      SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1532", ATTRS{idProduct}=="00e3", TAG+="uaccess"
    '')
  ];
}
