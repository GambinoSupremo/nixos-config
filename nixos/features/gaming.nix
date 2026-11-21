# Gaming: Steam, gamescope, GameMode, kernel settings for games, and the
# novpn launch option.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  # Hyprland skips its fullscreen rule when a game opens without focus (e.g. right
  # after a ProtonFixes popup), so this does it. Games tagged "windowed" in
  # dotfiles hypr/rule.lua are left alone.
  gameFullscreen = pkgs.writeShellScript "game-fullscreen" ''
    jq=${pkgs.jq}/bin/jq
    ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock" |
    while IFS= read -r ev; do
      case "$ev" in openwindow\>\>*) ;; *) continue ;; esac
      IFS=, read -r a _ cls title <<< "''${ev#openwindow>>}"
      case "$cls" in steam_app_*|*.exe) ;; *) continue ;; esac
      case "$title" in Launcher|broken) continue ;; esac
      sleep 1
      hyprctl clients -j | $jq -e --arg a "0x$a" '.[] | select(.address == $a and .fullscreen == 0 and (.floating | not) and (any(.tags[]; startswith("windowed")) | not))' >/dev/null || continue
      hyprctl dispatch "hl.dsp.focus({ window = \"address:0x$a\" })"
      hyprctl dispatch 'hl.dsp.window.fullscreen({ mode = "fullscreen", action = "set" })'
    done
  '';
in
lib.mkIf config.gav.features.gaming.enable {
  # --- Deadlock Mod Manager ---
  # Download it prebuilt instead of compiling it.
  nix.settings = {
    substituters = [ "https://deadlock-mod-manager.cachix.org" ];
    trusted-public-keys = [
      "deadlock-mod-manager.cachix.org-1:wUjtzL6yN2i9zTq1YrXHBr0mx3LP7tBGsosk3N+/A/M="
    ];
  };

  # --- Fullscreen new game windows ---
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

  # --- Steam ---
  programs.steam = {
    enable = true;
    # Stops Steam's windows coming up huge after a Sunshine stream.
    package = pkgs.steam.override { extraEnv.STEAM_FORCE_DESKTOPUI_SCALING = "1"; };
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    extraCompatPackages = with pkgs; [ proton-ge-bin ];
    extest.enable = true; # makes controller-as-mouse work on Wayland
    protontricks.enable = true;
  };

  # --- Gamescope ---
  programs.gamescope = {
    enable = true;
    capSysNice = true; # keeps it smooth when the CPU is busy
  };

  # --- Screen recording ---
  # Used by the menu's Capture entry.
  programs.gpu-screen-recorder.enable = true;

  # --- GameMode ---
  # Switched on in base/services.nix; this is what it does when a game starts.
  programs.gamemode.settings = {
    general = {
      desiredgov = "performance";
      softrealtime = "auto";
      reaper_freq = 5; # seconds between checks
      inhibit_screensaver = 1;
    };
  };

  # --- Kernel settings ---
  # ntsync: faster Windows-game sync for Proton.
  boot.kernelModules = [ "ntsync" ];
  services.udev.extraRules = ''
    KERNEL=="ntsync", MODE="0644"
  '';

  services.scx-loader = {
    enable = true;
    config.default_sched = "scx_bpfland"; # not scx_lavd: it freezes the PC on kernel 7.2+
  };

  boot.kernel.sysctl."vm.max_map_count" = 2147483642;

  # Left on, this makes several Proton games stutter badly.
  boot.kernel.sysctl."kernel.split_lock_mitigate" = 0;

  # --- Lutris fixes ---
  # Lutris still bundles gtk2, which nixpkgs marks broken.
  nixpkgs.config.problems.handlers."gtk+".broken = "ignore";

  # Lutris 0.5.22 crashes at startup with the current gnome-desktop.
  # Drop this once Lutris fixes it.
  nixpkgs.overlays = [
    (_final: prev: {
      lutris-unwrapped = prev.lutris-unwrapped.overrideAttrs (o: {
        postPatch = (o.postPatch or "") + ''
          substituteInPlace lutris/util/display.py \
            --replace-fail "except GLib.Error:" "except (GLib.Error, AttributeError):"
        '';
      });
    })
  ];

  # --- Programs ---
  environment.systemPackages = with pkgs; [
    # `novpn %command%`: runs a game outside the VPN. mullvad-exclude
    # doesn't work inside Steam, so this asks the Mullvad service instead.
    (writeShellScriptBin "novpn" ''
      mullvad split-tunnel add $$ >/dev/null 2>&1 || true
      exec "$@"
    '')
    lutris
    wowup-cf # WoW addon manager
    mangohud
    inputs.deadlock-mod-manager.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
