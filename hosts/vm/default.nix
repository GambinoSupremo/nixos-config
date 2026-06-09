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

  # Temporary recovery mode:
  # Disable greetd/Mango autostart so the VM always boots to a usable tty.
  services.greetd.enable = lib.mkForce false;
  services.getty.autologinUser = "gav";

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  hardware.graphics.enable = true;

  # Temporary VM debugging SSH.
  services.openssh.enable = true;
  services.openssh.settings = {
    PasswordAuthentication = lib.mkForce true;
    KbdInteractiveAuthentication = lib.mkForce true;
  };

  services.sunshine.enable = lib.mkForce false;
  hardware.openrazer.enable = lib.mkForce false;
  hardware.bluetooth.enable = lib.mkForce false;
  services.blueman.enable = lib.mkForce false;
  programs.gamemode.enable = lib.mkForce false;
}
