# Systemd user services owned by home-manager. Currently only the Mullvad
# GUI launcher (the daemon is a system service in nixos/base/networking.nix).
{ pkgs, lib, osConfig ? {}, ... }:

let
  isVM = osConfig.services.qemuGuest.enable or false;
in
{
  # ── Mullvad VPN GUI ───────────────────────────────────────────────────────────
  # Systemd user service instead of XDG autostart; waits for the system daemon
  # so the GUI doesn't show "App is out of sync" at login.
  systemd.user.services.mullvad-gui = lib.mkIf (!isVM) (
    let
      # Bounded poll (user units can't After= system units); an unbounded loop
      # here once hung rebuild switches. Past deadline, launch anyway.
      waitDaemon = pkgs.writeShellScript "mullvad-daemon-wait" ''
        for _ in $(seq 1 30); do
          systemctl is-active --quiet mullvad-daemon.service && exit 0
          sleep 1
        done
        exit 0
      '';
    in {
      Unit = {
        Description = "Mullvad VPN GUI";
        After       = [ "graphical-session.target" ];
        PartOf      = [ "graphical-session.target" ];
      };
      Service = {
        Type         = "simple";
        ExecStartPre = toString waitDaemon;
        ExecStart    = "${pkgs.mullvad-vpn}/bin/mullvad-vpn";
        Restart      = "on-failure";
        RestartSec   = "5s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    }
  );
}
