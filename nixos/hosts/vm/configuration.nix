# Test build only: checks the shared settings without the desktop's hardware
# (no GPU, Bluetooth or gaming). No real VM runs from it.
{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../base
  ];

  boot.loader.grub.device = "/dev/sda";

  # --- VM helpers ---
  # So it would still boot and be usable if it ever did run as a VM.
  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true; # clipboard and auto-resize

  # --- Graphics ---
  # No real GPU, so let the desktop draw in software.
  hardware.graphics.enable = true;
  environment.sessionVariables.WLR_RENDERER_ALLOW_SOFTWARE = "1";

  # --- Switched off here ---
  # base/services.nix turns these on for the real PC.
  hardware.bluetooth.enable = lib.mkForce false;
  services.blueman.enable = lib.mkForce false;
  programs.gamemode.enable = lib.mkForce false;
}
