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
    inputs.silentSDDM.nixosModules.default
  ];

  programs.silentSDDM = {
    enable = true;
    theme  = "default";
  };

  networking.hostName = "gavos";

  # KDE Plasma 6 — available as a session in SDDM alongside MangoWM/Niri/Hyprland
  services.desktopManager.plasma6.enable = true;
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    plasma-browser-integration
    oxygen
    elisa
    kmail
    kontact
    korganizer
  ];

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
