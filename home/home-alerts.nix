# home-alerts: Uptime Kuma's ntfy alerts (same topic as the phone) as desktop
# notifications. The topic is a secret, so its URL lives outside the repo in
# ~/.config/home-alerts/url (e.g. https://ntfy.sh/<topic>); no file, no service.
{
  pkgs,
  lib,
  host,
  ...
}:

let
  # Kuma sends down alerts at priority 5 and recoveries at 2.
  notify = pkgs.writeShellScript "home-alerts-notify" ''
    urgency=normal
    [ "''${NTFY_PRIORITY:-3}" -ge 4 ] && urgency=critical
    [ "''${NTFY_PRIORITY:-3}" -le 2 ] && urgency=low
    exec ${pkgs.libnotify}/bin/notify-send --app-name="Home alerts" --urgency="$urgency" \
      "''${NTFY_TITLE:-Home alert}" "$NTFY_MESSAGE"
  '';
  subscribe = pkgs.writeShellScript "home-alerts" ''
    exec ${lib.getExe' pkgs.ntfy-sh "ntfy"} subscribe "$(< "$HOME/.config/home-alerts/url")" ${notify}
  '';
in
{
  systemd.user.services.home-alerts = lib.mkIf (!host.isVM) {
    Unit = {
      Description = "Uptime Kuma alerts as desktop notifications";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      ConditionPathExists = "%h/.config/home-alerts/url";
    };
    Service = {
      ExecStart = toString subscribe;
      # ntfy reconnects on its own; this covers it giving up.
      Restart = "always";
      RestartSec = 30;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
