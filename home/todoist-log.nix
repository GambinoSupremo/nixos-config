# todoist-log: Todoist check-offs (recurring ones too) → "## Done" in the Obsidian daily notes.
# Run `todoist-log login` once; the timer then checks every 30 min and writes while Obsidian is open.
{
  pkgs,
  lib,
  config,
  host,
  ...
}:

let
  todoist-log = pkgs.writeShellApplication {
    name = "todoist-log";
    text = ''
      export DAILY_NOTE_FOLDER=${lib.escapeShellArg config.gav.dailyNote.folder}
      export DAILY_NOTE_FORMAT=${lib.escapeShellArg config.gav.dailyNote.format}
      exec ${pkgs.python3}/bin/python3 -I ${./todoist-log.py} "${config.home.homeDirectory}/Documents/Personal" "''${1:-sync}"
    '';
  };
in
lib.mkIf (!host.isVM) {
  home.packages = [ todoist-log ];

  systemd.user.services.todoist-log = {
    Unit.Description = "Todoist check-offs → Obsidian daily notes";
    Service = {
      Type = "oneshot";
      ExecStart = "${todoist-log}/bin/todoist-log auto";
    };
  };
  systemd.user.timers.todoist-log = {
    Unit.Description = "Log Todoist check-offs to Obsidian every 30 minutes";
    Timer = {
      OnStartupSec = "4min";
      OnUnitActiveSec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
