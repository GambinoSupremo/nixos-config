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
  ];

  networking.hostName = "gavos";
}
