# Gaming: Steam (+extest, protontricks), gamescope, gamemode tuning,
# game-friendly sysctls, and the novpn launch-option wrapper.
{ pkgs, inputs, ... }:

{
  # Millennium (Steam theming/plugin patcher) isn't in nixpkgs — pulled from
  # its own flake and wired in as the Steam package below.
  nixpkgs.overlays = [ inputs.millennium.overlays.default ];

  programs.steam = {
    enable = true;
    package = pkgs.millennium-steam;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
    # Controller-as-mouse comes in as XTEST (X11-only, dead on Wayland);
    # extest rewrites it into real uinput events.
    extest.enable = true;
    protontricks.enable = true;
  };

  # HDR + VRR scaler; use --hdr-enabled for the AW3423DW
  programs.gamescope = {
    enable = true;
    capSysNice = true;   # lets gamescope keep its compositor thread scheduled under load
  };

  # enable lives in services.nix; this is what gamemode does when a game starts.
  programs.gamemode.settings = {
    general = {
      desiredgov          = "performance";   # switch CPU governor while gaming
      softrealtime        = "auto";          # real-time scheduling if available
      reaper_freq         = 5;               # poll interval (seconds)
      inhibit_screensaver = 1;
    };
  };

  boot.kernelModules = [ "ntsync" ];
  services.udev.extraRules = ''
    KERNEL=="ntsync", MODE="0644"
  '';

  services.scx = {
    enable    = true;
    scheduler = "scx_bpfland"; # scx_lavd RCU-stalls the whole system on kernel 7.2.0+
  };

  boot.kernel.sysctl."vm.max_map_count" = 2147483642;

  # Split-lock mitigation throttles cores on misaligned atomics — several
  # Proton games trip it constantly (huge stutter). No untrusted tenants: off.
  boot.kernel.sysctl."kernel.split_lock_mitigate" = 0;

  environment.systemPackages = with pkgs; [
    # `novpn %command%`: game outside the Mullvad tunnel via daemon RPC — setuid
    # mullvad-exclude dies in Steam's nosuid sandbox; exec keeps the PID.
    (writeShellScriptBin "novpn" ''
      mullvad split-tunnel add $$ >/dev/null 2>&1 || true
      exec "$@"
    '')
    lutris
    heroic
    mangohud
    # obs-studio and plugins managed via programs.obs-studio in home/default.nix
  ];
}
