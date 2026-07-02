{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
  };

  # programs.gamemode.enable is set in services.nix.
  # Settings here configure what gamemode actually does when a game starts.
  programs.gamemode.settings = {
    general = {
      desiredgov          = "performance";   # switch CPU governor while gaming
      softrealtime        = "auto";          # real-time scheduling if available
      reaper_freq         = 5;               # poll interval (seconds)
      inhibit_screensaver = 1;
    };
    gpu = {
      # Requires gamemode to run as root or with CAP_SYS_NICE. If GPU opts
      # cause a startup error, comment this section out.
      apply_gpu_optimisations = "accept-responsibility";
      gpu_device              = 0;
      nv_powermizer_mode      = 1;    # 1 = Prefer Maximum Performance
    };
  };

  boot.kernel.sysctl."vm.max_map_count" = 2147483642;

  environment.systemPackages = with pkgs; [
    lutris
    heroic
    protonup-qt
    gamescope      # HDR + VRR scaler; use --hdr-enabled for the AW3423DW
    mangohud
    # obs-studio and plugins managed via programs.obs-studio in home/default.nix
  ];
}
