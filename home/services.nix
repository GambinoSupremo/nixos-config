# Systemd user services owned by home-manager: the Mullvad GUI launcher (daemon is a
# system service in nixos/base/networking.nix) and the Noctalia game-toast watcher.
{
  pkgs,
  lib,
  host,
  osConfig,
  ...
}:

let
  inherit (host) isVM;
  inherit (osConfig.gav.sessions) mango;
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

  # ── Noctalia Do Not Disturb while gaming ──────────────────────────────────────
  # A toast (or the config reload moving toasts used to need) breaks the game's pointer
  # lock, so while a game is open or fullscreen on the Alienware, DND is on.
  systemd.user.services.noctalia-game-toasts = lib.mkIf (!isVM) (
    let
      jq = "${pkgs.jq}/bin/jq";
      watcher = pkgs.writeShellScript "noctalia-game-toasts" ''
        cur=unset
        # $1 = on|off. Leaves DND alone if you'd already turned it on yourself.
        quiet() {
          [ "$1" = "$cur" ] && return
          cur=$1
          if [ "$1" = on ]; then
            mine=$(noctalia msg notification-dnd-status 2>/dev/null)
            [ "$mine" = off ] && noctalia msg notification-dnd-set on >/dev/null 2>&1
          else
            [ "''${mine:-}" = off ] && noctalia msg notification-dnd-set off >/dev/null 2>&1
            mine=""
          fi
        }
        apply() {
          mons=$(hyprctl monitors -j) || return
          ws=$(echo "$mons" | ${jq} '.[] | select(.model == "Dell AW3423DW") | .activeWorkspace.id')
          if [ -n "$ws" ] &&
             { hyprctl workspaces -j | ${jq} -e --argjson w "$ws" 'any(.[]; .id == $w and .hasfullscreen)' ||
               hyprctl clients -j | ${jq} -e --argjson w "$ws" 'any(.[]; .workspace.id == $w and (.class | test("^steam_app_|[.]exe$")))'; } >/dev/null; then
            quiet on
          else
            quiet off
          fi
        }
        ${lib.optionalString mango ''
          mmsg=${pkgs.mango}/bin/mmsg
          mango_apply() {
            outs=$(${pkgs.wlr-randr}/bin/wlr-randr --json) || return
            aw=$(echo "$outs" | ${jq} -r '.[] | select(.model == "Dell AW3423DW") | .name')
            if [ -n "$aw" ] &&
               $mmsg get all-clients | ${jq} -e --arg m "$aw" 'any(.clients[]; .monitor == $m and .is_fullscreen and .is_visible)' >/dev/null; then
              quiet on
            else
              quiet off
            fi
          }
        ''}
        trap 'cur=unset; quiet off; exit 0' TERM INT
        # Idles outside Hyprland/Mango sessions; reattaches if the compositor restarts.
        while :; do
          ${lib.optionalString mango ''
            msock=$(ls -t "$XDG_RUNTIME_DIR"/mango-*.sock 2>/dev/null | head -1)
            if [ -n "$msock" ] && MANGO_INSTANCE_SIGNATURE=$msock $mmsg get version >/dev/null 2>&1; then
              export MANGO_INSTANCE_SIGNATURE=$msock
              # wlr-randr needs the session's display; the unit may predate it.
              export WAYLAND_DISPLAY=$(systemctl --user show-environment | sed -n 's/^WAYLAND_DISPLAY=//p')
              mango_apply
              { $mmsg watch all-clients & $mmsg watch all-tags; } 2>/dev/null |
              while IFS= read -r _; do mango_apply; done
              cur=unset; quiet off
              sleep 5
              continue
            fi
          ''}
          sig=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)
          sock="$XDG_RUNTIME_DIR/hypr/$sig/.socket2.sock"
          if [ -n "$sig" ] && [ -S "$sock" ]; then
            export HYPRLAND_INSTANCE_SIGNATURE=$sig
            apply
            ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$sock" 2>/dev/null |
            while IFS= read -r ev; do
              case "''${ev%%>>*}" in
                fullscreen|workspacev2|openwindow|closewindow|movewindowv2|moveworkspacev2|monitoraddedv2|monitorremovedv2) apply ;;
              esac
            done
            cur=unset; quiet off
          fi
          sleep 5
        done
      '';
    in
    {
      Unit = {
        Description = "Noctalia Do Not Disturb while a game is open on the Alienware";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = toString watcher;
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    }
  );
}
