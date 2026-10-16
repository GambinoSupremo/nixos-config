# Logs Plex playback into the Obsidian Collections (desktop only). Plex webhook
# URL: http://10.0.0.52:8765/ (port opened on the LAN interface in hosts/desktop).
# On login it catches up from Plex history; that needs this PC allowed without auth
# in Plex (Settings > Network) or a token in ~/.config/plex-token.
{
  pkgs,
  lib,
  config,
  host,
  ...
}:

lib.mkIf (!host.isVM) {
  systemd.user.services.plex-log = {
    Unit.Description = "Plex watch log for Obsidian";
    Service = {
      ExecStart = "${pkgs.python3}/bin/python3 -I ${./plex-log.py} ${config.home.homeDirectory}/Documents/Personal 8765 10.0.0.11";
      Restart = "on-failure";
      RestartSec = "10s";
    };
    Install.WantedBy = [ "default.target" ];
  };
}
