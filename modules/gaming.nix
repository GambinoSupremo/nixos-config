{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    lutris
    heroic
    protonup-qt
    obs-studio-plugins.obs-vkcapture
    mangohud
  ];
}
