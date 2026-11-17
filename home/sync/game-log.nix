# game-log: Steam playtime → "## Played" in the Obsidian daily notes, every 15 min while Obsidian is open.
# game-watch: notes when non-Steam games (WoW) run, for game-log to add.
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
      export DAILY_NOTE_FOLDER=${lib.escapeShellArg config.gav.dailyNote.folder}
      export DAILY_NOTE_FORMAT=${lib.escapeShellArg config.gav.dailyNote.format}
      exec python3 -I ${./game-log.py} "${config.home.homeDirectory}/Documents/Personal" "$@"
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
  systemd.user.services.game-watch = {
    Unit.Description = "Record when non-Steam games run (for game-log)";
    Service = {
      ExecStart = "${game-log}/bin/game-log --watch";
      Restart = "on-failure";
      RestartSec = 30;
      Nice = 19;
    };
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.timers.game-log = {
    Unit.Description = "Log Steam playtime to Obsidian every 15 minutes";
    Timer = {
      OnStartupSec = "5min";
      OnUnitActiveSec = "15min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
