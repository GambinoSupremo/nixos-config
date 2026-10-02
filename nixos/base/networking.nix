# NetworkManager, nftables firewall, Mullvad daemon, systemd-resolved.
{ config, pkgs, ... }:

{
  networking = {
    networkmanager.enable = true;

    # NixOS firewall wraps nftables directly — ufw is not needed.
    # Open specific ports here rather than via ufw rules.
    firewall = {
      enable = true;
      # Sunshine streaming ports are opened by services.sunshine.openFirewall
      # (nixos/features/sunshine.nix).
    };
  };

  # Mullvad daemon. First boot: mullvad account login
  services.mullvad-vpn = {
    enable     = true;
    gui.enable = true;
  };

  # Keeper's AWS firewall 403s some Mullvad exit IPs (extension login just bounces).
  # On each connect, probe Keeper and reconnect to a fresh relay if blocked.
  systemd.services.mullvad-keeper-check = {
    description = "Reconnect Mullvad when Keeper blocks the relay";
    after    = [ "mullvad-daemon.service" ];
    bindsTo  = [ "mullvad-daemon.service" ];
    # multi-user.target too, so a rebuild starts it while the daemon is already running.
    wantedBy = [ "multi-user.target" "mullvad-daemon.service" ];
    path = [ config.services.mullvad-vpn.package pkgs.curl pkgs.coreutils ];
    script = ''
      tries=0
      mullvad status listen | while read -r line; do
        case "$line" in Connected*) ;; *) continue ;; esac
        sleep 3
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 https://keepersecurity.com/vault/ || true)
        if [ "$code" = 403 ] && [ "$tries" -lt 5 ]; then
          tries=$((tries + 1))
          echo "Keeper 403 on this relay, reconnecting (attempt $tries)"
          mullvad reconnect
        else
          [ "$code" = 403 ] && echo "Keeper still 403 after $tries reconnects, giving up"
          tries=0
        fi
      done
    '';
    serviceConfig = {
      Restart    = "always";
      RestartSec = "10s";
    };
  };

  # systemd-resolved for local DNS caching.
  # DNSSEC must be false — it breaks Mullvad's DNS.
  services.resolved = {
    enable  = true;
    settings.Resolve.DNSSEC = "false";
    # Don't set domains = [ "~." ] here — let Mullvad manage the split-tunnel DNS
  };
}
