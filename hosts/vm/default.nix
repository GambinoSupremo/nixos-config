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

  # Autologin directly into MangoWM.
  # initial_session runs on first boot; after logout falls back to tuigreet picker.
  services.greetd.settings = lib.mkForce {
    default_session = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --remember --remember-session --sessions ${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
      user    = "greeter";
    };
    initial_session = {
      command = "mango";
      user    = "gav";
    };
  };

  # QEMU guest agent — graceful shutdown, snapshot integration with Proxmox
  services.qemuGuest.enable = true;

  # SPICE agent — clipboard passthrough + dynamic resolution
  services.spice-vdagentd.enable = true;

  hardware.graphics.enable = true;

  # Disable services that do not make sense in a VM
  services.sunshine.enable   = lib.mkForce false;
  hardware.openrazer.enable  = lib.mkForce false;
  hardware.bluetooth.enable  = lib.mkForce false;
  services.blueman.enable    = lib.mkForce false;
  programs.gamemode.enable   = lib.mkForce false;
}
