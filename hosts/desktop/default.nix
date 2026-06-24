{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware.nix
    ./hardware-nvidia.nix
    ../../modules/core.nix
    ../../modules/users.nix
    ../../modules/networking.nix
    ../../modules/desktop.nix
    ../../modules/audio.nix
    ../../modules/services.nix
    ../../modules/packages.nix
    ../../modules/gaming.nix
  ];

  networking.hostName = "gavos";

  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Btrfs snapshots for /home
  services.snapper.configs.home = {
    SUBVOLUME        = "/home";
    ALLOW_USERS      = [ "gav" ];
    TIMELINE_CREATE  = true;
    TIMELINE_CLEANUP = true;
  };

  environment.systemPackages = with pkgs; [
    btrfs-assistant
    snapper
  ];
}
