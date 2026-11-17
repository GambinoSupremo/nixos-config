# Mullvad's window at login (the VPN itself is in nixos/base/networking.nix)
# and quieter Bluetooth notifications.
{
  pkgs,
  lib,
  host,
  ...
}:

let
  inherit (host) isVM;
in
{
  # --- Mullvad window ---
  # Opens once the VPN service is up, so it doesn't say "App is out of sync".
  systemd.user.services.mullvad-gui = lib.mkIf (!isVM) (
    let
      # Waits 30 seconds at most, then opens anyway.
      waitDaemon = pkgs.writeShellScript "mullvad-daemon-wait" ''
        for _ in $(seq 1 30); do
          systemctl is-active --quiet mullvad-daemon.service && exit 0
          sleep 1
        done
        exit 0
      '';
    in
    {
      Unit = {
        Description = "Mullvad VPN GUI";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "simple";
        ExecStartPre = toString waitDaemon;
        ExecStart = "${pkgs.mullvad-vpn}/bin/mullvad-vpn";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    }
  );

  # --- Bluetooth ---
  # No popup every time a device connects or drops.
  dconf.settings."org/blueman/general".plugin-list = lib.mkIf (!isVM) [ "!ConnectionNotifier" ];
}
