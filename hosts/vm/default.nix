{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/core.nix
    ../../modules/users.nix
    ../../modules/networking.nix
    ../../modules/desktop.nix
    ../../modules/audio.nix
    ../../modules/services.nix
    ../../modules/packages.nix
  ];

  networking.hostName = "nix-vm";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # QEMU guest agent — graceful shutdown, snapshot integration with Proxmox
  services.qemuGuest.enable = true;

  # modules/desktop.nix enables SDDM globally. The desktop uses an X11 greeter
  # (SilentSDDM targets X11). In the VM there is no reason for X11, so use the
  # Wayland SDDM backend instead to satisfy the assertion.
  services.displayManager.sddm.wayland.enable = true;

  # SPICE agent — clipboard passthrough + dynamic resolution in Proxmox console
  services.spice-vdagentd.enable = true;

  # virtio-gpu / llvmpipe is enough for the wlroots compositors; no GPU config here.
  # When moving to the physical desktop, add a hardware-nvidia.nix module instead.
  hardware.graphics.enable = true;

  # Let wlroots compositors (Mango) fall back to software rendering when the
  # VM exposes no usable GPU acceleration.
  environment.sessionVariables.WLR_RENDERER_ALLOW_SOFTWARE = "1";

  # Desktop-hardware services that make no sense in a VM.
  # mkForce because modules/services.nix enables them for the physical machine.
  hardware.openrazer.enable = lib.mkForce false;  # no Razer hardware in VM
  hardware.bluetooth.enable = lib.mkForce false;  # no BT in VM
  services.blueman.enable   = lib.mkForce false;
  programs.gamemode.enable  = lib.mkForce false;  # pointless without a GPU
}
