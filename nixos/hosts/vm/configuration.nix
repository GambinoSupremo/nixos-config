# Proxmox VM — no GPU (software rendering), physical-hardware services
# forced off. Used as a safe testbed for the shared modules.
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../base/core.nix
    ../../base/users.nix
    ../../base/networking.nix
    ../../features/desktop.nix
    ../../base/audio.nix
    ../../base/services.nix
    ../../base/packages.nix
  ];

  networking.hostName = "nix-vm";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # QEMU guest agent — graceful shutdown, snapshot integration with Proxmox
  services.qemuGuest.enable = true;

  # Wayland greeter — no reason for X11 in the VM.
  services.displayManager.sddm.wayland.enable = true;

  # SPICE agent — clipboard passthrough + dynamic resolution in Proxmox console
  services.spice-vdagentd.enable = true;

  # virtio-gpu / llvmpipe is enough for the wlroots compositors; no GPU config here.
  # When moving to the physical desktop, import nixos/features/nvidia.nix instead.
  hardware.graphics.enable = true;

  # Let wlroots compositors (Mango) fall back to software rendering when the
  # VM exposes no usable GPU acceleration.
  environment.sessionVariables.WLR_RENDERER_ALLOW_SOFTWARE = "1";

  # Desktop-hardware services that make no sense in a VM.
  # mkForce because nixos/base/services.nix enables them for the physical machine.
  hardware.openrazer.enable = lib.mkForce false;  # no Razer hardware in VM
  hardware.bluetooth.enable = lib.mkForce false;  # no BT in VM
  services.blueman.enable   = lib.mkForce false;
  programs.gamemode.enable  = lib.mkForce false;  # pointless without a GPU
}
