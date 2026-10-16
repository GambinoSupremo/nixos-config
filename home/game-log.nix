# game-log: Steam playtime → "## Played" in the Obsidian daily notes, hourly and at login.
{
  pkgs,
  lib,
  config,
  host,
  ...
}:

let
  game-log = pkgs.writeShellApplication {
    name = "game-log";
    runtimeInputs = [
      pkgs.procps
      pkgs.python3
    ];
    text = ''
      exec python3 -I ${./game-log.py} "${config.home.homeDirectory}/Documents/Personal"
    '';
  };
in
lib.mkIf (!host.isVM) {
  home.packages = [ game-log ];

  systemd.user.services.game-log = {
    Unit.Description = "Steam playtime → Obsidian daily notes";
    Service = {
      Type = "oneshot";
      ExecStart = "${game-log}/bin/game-log";
    };
  };
  systemd.user.timers.game-log = {
    Unit.Description = "Log Steam playtime to Obsidian every hour";
    Timer = {
      OnStartupSec = "5min";
      OnUnitActiveSec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
