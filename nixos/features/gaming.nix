# Gaming: Steam (+extest, protontricks), gamescope, gamemode tuning,
# game-friendly sysctls, and the novpn launch-option wrapper.
{ pkgs, ... }:

{
  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
    # Steam injects desktop-mode controller input (Steam Controller trackpad
    # mouse) as XTEST — X11-only fake input that never reaches the Wayland
    # cursor, so the pointer only "works" over XWayland windows like Steam
    # itself. extest is preloaded into Steam and rewrites those XTEST calls
    # into real uinput events.
    extest.enable = true;
    protontricks.enable = true;
  };

  # HDR + VRR scaler; use --hdr-enabled for the AW3423DW
  programs.gamescope = {
    enable = true;
    capSysNice = true;   # lets gamescope keep its compositor thread scheduled under load
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

  # Split-lock mitigation throttles a core hard when a process does a
  # misaligned atomic — a server-side protection that several Windows games
  # trip constantly under Proton (God of War, THPS1+2, Sable, ...), showing
  # up as massive unexplained stutter. Desktop box, no untrusted tenants:
  # turn it off.
  boot.kernel.sysctl."kernel.split_lock_mitigate" = 0;

  environment.systemPackages = with pkgs; [
    # Steam launch-option wrapper: `novpn %command%` runs the game outside the
    # Mullvad tunnel (EOS/P2P matchmaking fails behind the VPN — Rivals 2).
    # mullvad-exclude can't be used there: it's a setuid wrapper and Steam's
    # FHS/bwrap sandbox mounts nosuid, so it dies on the cgroup write. Instead
    # ask the daemon over RPC to exclude this PID; exec keeps the PID and
    # children inherit the exclusion cgroup.
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
