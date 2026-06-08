{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.common-cpu-amd # Change if Intel
    ../../modules/core.nix
    ../../modules/users.nix
    ../../modules/networking.nix
    ../../modules/desktop.nix
    ../../modules/audio.nix
    ../../modules/services.nix
    ../../modules/packages.nix
    ../../modules/hardware/amd.nix
  ];

  networking.hostName = "gavin-laptop";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Battery management
  services.tlp.enable = true;
  services.upower.enable = true;
}
