# Systemd user services owned by home-manager. Currently only the Mullvad
# GUI launcher (the daemon is a system service in nixos/base/networking.nix).
{ pkgs, lib, osConfig ? {}, ... }:

let
  isVM = osConfig.services.qemuGuest.enable or false;
in
{
  # ── Mullvad VPN GUI ───────────────────────────────────────────────────────────
  # Replaces the XDG autostart entry (suppressed in dotfiles.nix) with a systemd
  # user service. ExecStartPre waits until the system daemon is active before
  # launching the GUI, preventing the "App is out of sync" error at login.
  # Both ExecStart and the daemon come from pkgs.mullvad-vpn so versions match.
  systemd.user.services.mullvad-gui = lib.mkIf (!isVM) (
    let
      waitDaemon = pkgs.writeShellScript "mullvad-daemon-wait" ''
        until systemctl is-active --quiet mullvad-daemon.service; do
          sleep 1
        done
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
