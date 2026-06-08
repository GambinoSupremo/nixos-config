{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core.nix
    ../../modules/users.nix
    ../../modules/networking.nix
    ../../modules/desktop.nix
    ../../modules/audio.nix
    ../../modules/services.nix
    ../../modules/packages.nix
    ../../modules/gaming.nix
    ../../modules/hardware/nvidia.nix
  ];

  networking.hostName = "gavin-pc";

  # CachyOS kernel — BORE scheduler, NTSYNC, etc. (provided by chaotic-nyx)
  boot.kernelPackages = pkgs.linuxPackages_cachyos;

  boot.loader.systemd-boot.enable      = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Btrfs snapshots
  services.snapper.configs.home = {
    SUBVOLUME        = "/home";
    ALLOW_USERS      = [ "gav" ];
    TIMELINE_CREATE  = true;
    TIMELINE_CLEANUP = true;
  };

  # Razer hardware
  hardware.openrazer.enable = true;
  hardware.openrazer.users  = [ "gav" ];

  # Game streaming
  services.sunshine = {
    enable       = true;
    openFirewall = true;
    capSysAdmin  = true;
  };

  # Ollama with CUDA on the desktop (overrides the CPU-only default in services.nix)
  services.ollama.acceleration = lib.mkForce "cuda";

  environment.systemPackages = with pkgs; [
    btrfs-assistant
    snapper
  ];
}
