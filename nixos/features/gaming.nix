# Gaming: Steam (+extest, protontricks), gamescope, gamemode tuning,
# game-friendly sysctls, and the novpn and hdr-game launch-option wrappers.
{
  config,
  pkgs,
  inputs,
  ...
}:

let
  # Hyprland's fullscreen window rule is skipped when the window maps without initial
  # focus (e.g. a ProtonFixes popup just closed), so make new game windows fullscreen here.
  gameFullscreen = pkgs.writeShellScript "game-fullscreen" ''
    jq=${pkgs.jq}/bin/jq
    ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
    while IFS= read -r ev; do
      case "$ev" in openwindow\>\>*) ;; *) continue ;; esac
      IFS=, read -r a _ cls title <<< "''${ev#openwindow>>}"
      case "$cls" in steam_app_*|*.exe) ;; *) continue ;; esac
      case "$title" in Launcher|broken) continue ;; esac
      sleep 1
      hyprctl clients -j | $jq -e --arg a "0x$a" '.[] | select(.address == $a and .fullscreen == 0 and (.floating | not))' >/dev/null || continue
      hyprctl dispatch "hl.dsp.focus({ window = \"address:0x$a\" })"
      hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set" })'
    done
  '';
in
{
  # Upstream's binary cache for the Deadlock Mod Manager flake input.
  nix.settings = {
    substituters = [ "https://deadlock-mod-manager.cachix.org" ];
    trusted-public-keys = [
      "deadlock-mod-manager.cachix.org-1:wUjtzL6yN2i9zTq1YrXHBr0mx3LP7tBGsosk3N+/A/M="
    ];
  };

  systemd.user.services.game-fullscreen = {
    description = "Fullscreen new game windows on Hyprland";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    path = [ config.programs.hyprland.package ];
    serviceConfig = {
      ExecStart = gameFullscreen;
      Restart = "on-failure";
    };
  };

  programs.steam = {
    enable = true;
    # Steam guesses UI scale from the X11 primary at launch; Sunshine's 0mm virtual output made it huge.
    package = pkgs.steam.override { extraEnv.STEAM_FORCE_DESKTOPUI_SCALING = "1"; };
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
    capSysNice = true; # lets gamescope keep its compositor thread scheduled under load
  };

  # enable lives in services.nix; this is what gamemode does when a game starts.
  programs.gamemode.settings = {
    general = {
      desiredgov = "performance"; # switch CPU governor while gaming
      softrealtime = "auto"; # real-time scheduling if available
      reaper_freq = 5; # poll interval (seconds)
      inhibit_screensaver = 1;
    };
  };

  boot.kernelModules = [ "ntsync" ];
  services.udev.extraRules = ''
    KERNEL=="ntsync", MODE="0644"
  '';

  services.scx = {
    enable = true;
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
    # `hdr-game %command%`: native Wayland + HDR at the desk (SDL covers native Linux
    # games); Remote Play can't capture Wayland game windows, so streamed launches stay on XWayland.
    (writeShellScriptBin "hdr-game" ''
      if [ "''${SteamStreaming:-0}" != 1 ]; then
        export PROTON_ENABLE_WAYLAND=1 PROTON_ENABLE_HDR=1 SDL_VIDEODRIVER=wayland
      fi
      exec "$@"
    '')
    lutris
    mangohud
    inputs.deadlock-mod-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
    # obs-studio and plugins managed via programs.obs-studio in home/default.nix
  ];
}
