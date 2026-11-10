# garmin-sync: Garmin Connect steps, sleep and workouts → Obsidian daily notes.
# Run `garmin-sync login` once; the timer then syncs every 3 hours while Obsidian is open
# (it checks every 30 min, so a skipped sync catches up soon after Obsidian opens).
{
  pkgs,
  lib,
  config,
  host,
  ...
}:

let
  python = pkgs.python3.withPackages (ps: [ ps.garminconnect ]);
  garmin-sync = pkgs.writeShellApplication {
    name = "garmin-sync";
    text = ''
      export DAILY_NOTE_FOLDER=${lib.escapeShellArg config.gav.dailyNote.folder}
      export DAILY_NOTE_FORMAT=${lib.escapeShellArg config.gav.dailyNote.format}
      exec ${python}/bin/python3 -I ${./garmin-sync.py} "${config.home.homeDirectory}/Documents/Personal" "''${1:-sync}"
    '';
  };
in
lib.mkIf (!host.isVM) {
  home.packages = [ garmin-sync ];

  systemd.user.services.garmin-sync = {
    Unit.Description = "Garmin Connect → Obsidian daily notes";
    Service = {
      Type = "oneshot";
      ExecStart = "${garmin-sync}/bin/garmin-sync auto";
    };
  };
  systemd.user.timers.garmin-sync = {
    Unit.Description = "Sync Garmin into Obsidian every few hours";
    Timer = {
      OnStartupSec = "3min";
      OnUnitActiveSec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
