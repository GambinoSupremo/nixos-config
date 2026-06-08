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

  # Autologin directly into Niri — no session picker needed on a dev VM.
  # initial_session runs once on boot; after logout it falls back to tuigreet.
  services.greetd.settings = lib.mkForce {
    default_session = {
      command = "${pkgs.greetd.tuigreet}/bin/tuigreet --time --cmd niri-session";
      user    = "greeter";
    };
    initial_session = {
      command = "niri-session";
      user    = "gav";
    };
  };

  # QEMU guest agent — graceful shutdown, snapshot integration with Proxmox
  services.qemuGuest.enable = true;

  # SPICE agent — clipboard passthrough + dynamic resolution in Proxmox console
  services.spice-vdagentd.enable = true;

  hardware.graphics.enable = true;

  # Disable services that do not make sense in a VM
  services.sunshine.enable      = lib.mkForce false;
  hardware.openrazer.enable     = lib.mkForce false;
  hardware.bluetooth.enable     = lib.mkForce false;
  services.blueman.enable       = lib.mkForce false;
  programs.gamemode.enable      = lib.mkForce false;
  programs.mango.enable         = lib.mkForce false;
}
