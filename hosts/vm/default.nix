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

  # Exactly as MangoWM docs recommend:
  # https://github.com/mangowm/mango#nixos
  services.greetd = lib.mkForce {
    enable = true;
    settings = {
      initial_session = {
        command = "mango";
        user    = "gav";
      };
      default_session = {
        command = "${pkgs.greetd.tuigreet}/bin/tuigreet --cmd mango";
        user    = "greeter";
      };
    };
  };

  services.qemuGuest.enable     = true;
  services.spice-vdagentd.enable = true;
  hardware.graphics.enable       = true;

  services.sunshine.enable  = lib.mkForce false;
  hardware.openrazer.enable = lib.mkForce false;
  hardware.bluetooth.enable = lib.mkForce false;
  services.blueman.enable   = lib.mkForce false;
  programs.gamemode.enable  = lib.mkForce false;
}
