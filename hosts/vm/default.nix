{ config, pkgs, lib, inputs, ...}:

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

  # Niri as the VM session (MangoWM disabled without GPU)
  services.displayManager.defaultSession = lib.mkForce "niri";

  # QEMU guest agent — graceful shutdown, snapshot integration with Proxmox
  services.qemuGuest.enable = true;

  # SPICE agent — clipboard passthrough + dynamic resolution in Proxmox console
  services.spice-vdagentd.enable = true;

  # VM has no GPU — disable anything that needs hardware acceleration
  # When moving to the physical desktop, pull these out and add a hardware-nvidia.nix module
  hardware.graphics.enable = true;
  # hardware.nvidia.*  → see future modules/hardware-nvidia.nix
  # lib32-nvidia-utils, libva-nvidia-driver, etc. go there

  # Disable services that don't make sense in a VM
  services.sunshine.enable      = lib.mkForce false;  # needs KMS capture; re-enable on physical
  hardware.openrazer.enable     = lib.mkForce false;  # no Razer hardware in VM
  hardware.bluetooth.enable     = lib.mkForce false;  # no BT in VM
  services.blueman.enable       = lib.mkForce false;
  programs.gamemode.enable      = lib.mkForce false;  # pointless without a GPU
  programs.mango.enable         = lib.mkForce false;  # MangoWM needs GPU; Niri is the VM compositor
}
