# Systemd user services owned by home-manager: the Mullvad GUI launcher (daemon is a
# system service in nixos/base/networking.nix) and the Noctalia game-toast watcher.
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

  # ── Noctalia toasts off the Alienware while gaming ────────────────────────────
  # Toast layer over a fullscreen game steals the pointer lock; move toasts to the Philips.
  systemd.user.services.noctalia-game-toasts = lib.mkIf (!isVM) (
    let
      jq = "${pkgs.jq}/bin/jq";
      watcher = pkgs.writeShellScript "noctalia-game-toasts" ''
        f="$HOME/.local/state/noctalia/settings.toml"
        cur=unset
        # $1 = monitors line for [notification], empty = all monitors.
        set_toasts() {
          [ "$1" = "$cur" ] && return
          cur=$1
          [ -f "$f" ] || return
          ${pkgs.gawk}/bin/awk -v line="$1" '
            /^\[/ { sec = ($0 == "[notification]"); print; if (sec && line != "") print line; next }
            sec && /^monitors = / { next }
            { print }' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
          noctalia msg config-reload >/dev/null 2>&1
        }
        apply() {
          mons=$(hyprctl monitors -j) || return
          ws=$(echo "$mons" | ${jq} '.[] | select(.model == "Dell AW3423DW") | .activeWorkspace.id')
          phl=$(echo "$mons" | ${jq} -r '.[] | select(.model == "PHL 278E1") | .name')
          if [ -n "$ws" ] && [ -n "$phl" ] &&
             hyprctl workspaces -j | ${jq} -e --argjson w "$ws" 'any(.[]; .id == $w and .hasfullscreen)' >/dev/null; then
            set_toasts "monitors = [ \"$phl\" ]"
          else
            set_toasts ""
          fi
        }
        trap 'cur=unset; set_toasts ""; exit 0' TERM INT
        # Idles outside Hyprland sessions; reattaches if Hyprland restarts.
        while :; do
          sig=$(ls -t "$XDG_RUNTIME_DIR/hypr" 2>/dev/null | head -1)
          sock="$XDG_RUNTIME_DIR/hypr/$sig/.socket2.sock"
          if [ -n "$sig" ] && [ -S "$sock" ]; then
            export HYPRLAND_INSTANCE_SIGNATURE=$sig
            apply
            ${pkgs.socat}/bin/socat -U - UNIX-CONNECT:"$sock" 2>/dev/null |
            while IFS= read -r ev; do
              case "''${ev%%>>*}" in
                fullscreen|workspacev2|closewindow|movewindowv2|moveworkspacev2|monitoraddedv2|monitorremovedv2) apply ;;
              esac
            done
            cur=unset; set_toasts ""
          fi
          sleep 5
        done
      '';
    in {
      Unit = {
        Description = "Keep Noctalia toasts off the Alienware during fullscreen games";
        After       = [ "graphical-session.target" ];
        PartOf      = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart  = toString watcher;
        Restart    = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    }
  );
}
