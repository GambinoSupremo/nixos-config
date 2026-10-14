# User account, groups, and login-shell registration.
{ pkgs, ... }:

{
  users.users.gav = {
    isNormalUser = true;
    description = "Gavin";
    shell = pkgs.fish;
    extraGroups = [
      "wheel" # sudo
      "networkmanager" # manage NetworkManager without sudo
      "video" # brightness control, video devices
      "audio" # audio devices (belt-and-suspenders with pipewire)
      "input" # keyd and input-remapper access
      "dialout" # /dev/ttyACM* — ZMK Studio serial, flashing
    ];
  };

  # Registers fish as a valid login shell system-wide and enables vendor completions.
  # User-level fish config (aliases, plugins, etc.) lives in home/default.nix.
  programs.fish.enable = true;

  # Allow passwordless sudo for wheel — remove if you want a sudo password
  # security.sudo.wheelNeedsPassword = false;
}
