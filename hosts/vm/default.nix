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

  # Use SDDM for the VM so we can choose sessions interactively.
  services.greetd.enable = lib.mkForce false;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  # Preselect Mango if SDDM sees the session name.
  # If this exact name does not match, SDDM will still show the session picker.
  services.displayManager.defaultSession = "mango";

  # Make sure sessions are visible to the display manager.
  services.displayManager.sessionPackages = [
    config.programs.mango.package
    pkgs.hyprland
    pkgs.niri
  ];

  services.qemuGuest.enable = true;
  services.spice-vdagentd.enable = true;
  hardware.graphics.enable = true;

  services.sunshine.enable = lib.mkForce false;
  hardware.openrazer.enable = lib.mkForce false;
  hardware.bluetooth.enable = lib.mkForce false;
  services.blueman.enable = lib.mkForce false;
  programs.gamemode.enable = lib.mkForce false;
}
