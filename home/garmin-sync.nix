# garmin-sync: Garmin Connect steps, sleep and workouts → Obsidian daily notes.
# Run `garmin-sync login` once; the timer then syncs at login and every 3 hours.
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
      OnUnitActiveSec = "3h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
