{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    inputs.nixos-hardware.nixosModules.common-cpu-amd # Change if Intel
    ../../base/core.nix
    ../../base/users.nix
    ../../base/networking.nix
    ../../features/desktop.nix
    ../../base/audio.nix
    ../../base/services.nix
    ../../base/packages.nix
    ../../features/amd.nix
  ];

  networking.hostName = "gavin-laptop";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Battery management
  services.tlp.enable = true;
  services.upower.enable = true;
}
