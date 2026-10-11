# Nightly encrypted copy of the NAS "personal" share to pCloud (desktop only).
# rclone remotes live in ~/.config/rclone/rclone.conf; nas-backup-setup makes them once.
{
  pkgs,
  lib,
  host,
  ...
}:

let
  # Sign in to the NAS and pCloud, and generate the encryption password (goes in Keeper).
  setup = pkgs.writeShellApplication {
    name = "nas-backup-setup";
    runtimeInputs = [
      pkgs.rclone
      pkgs.openssl
      pkgs.coreutils
      pkgs.systemd
    ];
    text = ''
      remotes=$(rclone listremotes)

      if [[ $remotes != *nas:* ]]; then
        echo "NAS login (the account you use for the Personal share)."
        read -rp "Username [gavin]: " user
        read -rsp "Password: " pass
        echo
        rclone config create nas smb host=10.0.0.117 user="''${user:-gavin}" pass="$pass" --obscure >/dev/null
      fi
      if ! rclone lsf --max-depth 1 nas:personal >/dev/null; then
        rclone config delete nas
        echo "Couldn't open the NAS Personal share with that login. Run nas-backup-setup again."
        exit 1
      fi
      echo "✓ NAS works"

      if [[ $remotes != *pcloud:* ]]; then
        echo "A browser window will open. Sign in to pCloud and click Allow."
        rclone config create pcloud pcloud >/dev/null
      fi
      rclone about pcloud: >/dev/null
      echo "✓ pCloud works"

      if [[ $remotes != *pcloud-crypt:* ]]; then
        pw=$(openssl rand -hex 16)
        echo
        echo "Backup encryption password:  $pw"
        echo "Save it in Keeper now (e.g. \"pCloud NAS backup\"). Without it the backup can't be opened."
        read -rp "Type saved once it's in Keeper: " ok
        if [[ $ok != saved ]]; then
          echo "Stopped. Nothing was created; run nas-backup-setup again."
          exit 1
        fi
        rclone config create pcloud-crypt crypt remote=pcloud:NAS-Backup password="$pw" --obscure >/dev/null
      fi
      echo "✓ Encryption set up"

      systemctl --user start --no-block nas-backup.service
      echo "First backup started in the background. You'll get a notification if it fails."
    '';
  };

  # Changed or deleted files go to changed/<date> instead of vanishing; kept 90 days.
  backup = pkgs.writeShellScript "nas-backup" ''
    set -euo pipefail
    PATH=${
      lib.makeBinPath [
        pkgs.rclone
        pkgs.coreutils
        pkgs.libnotify
      ]
    }
    fail() { notify-send -u critical "NAS backup failed" "$1 (journalctl --user -u nas-backup)"; exit 1; }

    if [[ $(rclone listremotes) != *pcloud-crypt:* ]]; then
      echo "Not set up yet; run nas-backup-setup."
      exit 0
    fi
    rclone sync nas:personal pcloud-crypt:current \
      --backup-dir "pcloud-crypt:changed/$(date +%F)" \
      --max-delete 1000 -v || fail "Copying to pCloud didn't finish"

    cutoff=$(date -d '90 days ago' +%F)
    # changed/ doesn't exist until something has changed.
    { rclone lsf --dirs-only pcloud-crypt:changed 2>/dev/null || true; } | while read -r d; do
      if [[ ''${d%/} < $cutoff ]]; then rclone purge "pcloud-crypt:changed/''${d%/}"; fi
    done
  '';
in
lib.mkIf (!host.isVM) {
  home.packages = [ setup ];

  systemd.user.services.nas-backup = {
    Unit.Description = "Encrypted backup of the NAS Personal share to pCloud";
    Service = {
      Type = "oneshot";
      ExecStart = toString backup;
      Nice = 10;
      IOSchedulingClass = "idle";
    };
  };

  # Persistent: if the PC was off at midnight, it runs soon after the next login.
  systemd.user.timers.nas-backup = {
    Unit.Description = "Nightly NAS to pCloud backup";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "15m";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
