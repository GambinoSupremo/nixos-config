# Proxmox VM — no GPU (software rendering), physical-hardware services
# forced off. Used as a safe testbed for the shared modules.
{ lib, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../base
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # QEMU guest agent — graceful shutdown, snapshot integration with Proxmox
  services.qemuGuest.enable = true;

  # SPICE agent — clipboard passthrough + dynamic resolution in Proxmox console
  services.spice-vdagentd.enable = true;

  # virtio-gpu / llvmpipe is enough for the wlroots compositors; no GPU config here.
  hardware.graphics.enable = true;

  # Let wlroots compositors fall back to software rendering when the
  # VM exposes no usable GPU acceleration.
  environment.sessionVariables.WLR_RENDERER_ALLOW_SOFTWARE = "1";

  # Desktop-hardware services that make no sense in a VM.
  # mkForce because nixos/base/services.nix enables them for the physical machine.
  hardware.openrazer.enable = lib.mkForce false; # no Razer hardware in VM
  hardware.bluetooth.enable = lib.mkForce false; # no BT in VM
  services.blueman.enable = lib.mkForce false;
  programs.gamemode.enable = lib.mkForce false; # pointless without a GPU
}
