# My user account and its groups.
{ pkgs, ... }:

{
  users.users.gav = {
    isNormalUser = true;
    description = "Gavin";
    shell = pkgs.fish;
    extraGroups = [
      "wheel" # sudo
      "networkmanager"
      "video"
      "audio"
      "input" # keyd
      "dialout" # keyboard flashing, ZMK Studio
      "i2c" # ddcutil monitor control
    ];
  };

  # Makes fish a valid login shell. My fish setup is home/terminal/shell.nix.
  programs.fish.enable = true;
}
