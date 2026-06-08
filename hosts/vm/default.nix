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

  # Override the greetd session from desktop.nix to drop straight into Niri for the VM
  services.greetd.settings.default_session.command = lib.mkForce "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd niri-session";

  # QEMU guest agent — graceful shutdown, snapshot integration with Proxmox
  services.qemuGuest.enable = true;

  # SPICE agent — clipboard passthrough + dynamic resolution in Proxmox console
  services.spice-vdagentd.enable = true;

  # VM has no GPU — disable anything that needs hardware acceleration
  hardware.graphics.enable = true;

  # Disable services that don't make sense in a VM
  services.sunshine.enable      = lib.mkForce false;  # needs KMS capture
  hardware.openrazer.enable     = lib.mkForce false;  # no Razer hardware in VM
  hardware.bluetooth.enable     = lib.mkForce false;  # no BT in VM
  services.blueman.enable       = lib.mkForce false;
  programs.gamemode.enable      = lib.mkForce false;  # pointless without a GPU
  programs.mango.enable         = lib.mkForce false;  # MangoWM needs GPU
}
