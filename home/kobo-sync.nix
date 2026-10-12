# kobo-sync: plug in the Kobo, run it, and its reading log updates Collections/Books.
{
  pkgs,
  lib,
  config,
  host,
  ...
}:

let
  kobo-sync = pkgs.writeShellApplication {
    name = "kobo-sync";
    runtimeInputs = [
      pkgs.util-linux
      pkgs.udisks
      pkgs.python3
    ];
    text = ''
      dev=$(lsblk -nrpo NAME,LABEL | awk '$2 == "KOBOeReader" {print $1; exit}')
      [[ -n "$dev" ]] || { echo "No Kobo found. Plug it in (and tap Connect on the Kobo if it asks)."; exit 1; }
      mnt=$(findmnt -nro TARGET "$dev" || true)
      mounted_here=""
      if [[ -z "$mnt" ]]; then
        udisksctl mount -b "$dev" -o ro >/dev/null
        mnt=$(findmnt -nro TARGET "$dev")
        mounted_here=1
      fi
      python3 -I ${./kobo-sync.py} "$mnt" "${config.home.homeDirectory}/Documents/Personal"
      if [[ -n "$mounted_here" ]]; then
        udisksctl unmount -b "$dev" >/dev/null && echo "Kobo is safe to unplug."
      fi
    '';
  };
in
lib.mkIf (!host.isVM) {
  home.packages = [ kobo-sync ];
}
