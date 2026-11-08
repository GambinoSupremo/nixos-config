# Systemd user services owned by home-manager: the Mullvad GUI launcher (daemon is a
# system service in nixos/base/networking.nix).
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

  # Blueman toasts on every BT connect/disconnect (Lily58 flaps); keep the applet, drop the toasts.
  dconf.settings."org/blueman/general".plugin-list = lib.mkIf (!isVM) [ "!ConnectionNotifier" ];

  # Started by the compositor bootstrap after importing its display environment.
  # Battle.net can drop a game launch request while still signing in after boot.
  systemd.user.services.battlenet-background = lib.mkIf (!isVM) {
    Unit = {
      Description = "Battle.net background login";
      PartOf = [ "graphical-session.target" ];
      ConditionPathExists = "%h/.local/share/lutris/games/battlenet-1793150466.yml";
    };
    Service = {
      Type = "simple";
      ExecStartPre = toString (
        pkgs.writeShellScript "battlenet-startup-settings" ''
          ${pkgs.python3}/bin/python3 - <<'PY'
          import json
          import shutil
          from pathlib import Path

          settings = Path.home() / "Games/battlenet/drive_c/users/steamuser/AppData/Roaming/Battle.net"
          for path in settings.glob("*.config"):
              data = json.loads(path.read_text())
              # 3 closes the window but stays signed in for later launches; 2 exits the client.
              client = data.get("Client") if path.name == "Battle.net.config" else data.get("User", {}).get("Client")
              if not isinstance(client, dict):
                  continue
              key, value = ("GameLaunchWindowBehavior", "3") if path.name == "Battle.net.config" else ("MinimizedOnStartup", "true")
              if client.get(key) == value:
                  continue
              backup = path.with_suffix(".config.before-background-login")
              if not backup.exists():
                  shutil.copy2(path, backup)
              client[key] = value
              temp = path.with_suffix(".config.tmp")
              temp.write_text(json.dumps(data, indent=4) + "\n")
              temp.replace(path)

          game = Path.home() / ".local/share/lutris/games/battlenet-1793150466.yml"
          text = game.read_text()
          if "  args:" not in text.split("game_slug:", 1)[0]:
              backup = game.with_suffix(".yml.before-background-login")
              if not backup.exists():
                  shutil.copy2(game, backup)
              game.write_text(text.replace("game:\n", "game:\n  args: --autostarted\n", 1))
          PY
        ''
      );
      ExecStart = "${pkgs.coreutils}/bin/env LUTRIS_SKIP_INIT=1 ${pkgs.lutris}/bin/lutris lutris:rungameid/1";
      Restart = "no";
    };
  };
}
