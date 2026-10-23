# Keeps Deadlock's wider camera: game updates, Steam's verify and the mod manager
# rewrite gameinfo.gi and drop r_aspectratio, so put it back whenever the file changes.
{
  lib,
  pkgs,
  host,
  ...
}:

let
  gameinfo = "%h/.local/share/Steam/steamapps/common/Deadlock/game/citadel/gameinfo.gi";

  deadlock-fov = pkgs.writeShellApplication {
    name = "deadlock-fov";
    runtimeInputs = [
      pkgs.gnugrep
      pkgs.gnused
    ];
    text = ''
      f="$HOME/.local/share/Steam/steamapps/common/Deadlock/game/citadel/gameinfo.gi"
      [ -f "$f" ] || exit 0
      grep -q '"r_aspectratio"' "$f" && exit 0
      # The file uses CRLF; slot the line in after a ConVar every version has had.
      if ! grep -qP '^\t\t"cl_usesocketsforloopback"' "$f"; then
        echo "anchor line not found, r_aspectratio not added" >&2
        exit 1
      fi
      sed -i 's|^\(\t\t"cl_usesocketsforloopback".*\r\)$|\1\n\t\t"r_aspectratio" "2.7"\r|' "$f"
      echo "added r_aspectratio 2.7"
    '';
  };
in
lib.mkIf (!host.isVM) {
  home.packages = [ deadlock-fov ];

  systemd.user.services.deadlock-fov = {
    Unit.Description = "Re-add r_aspectratio to Deadlock's gameinfo.gi";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe deadlock-fov;
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.paths.deadlock-fov = {
    Unit.Description = "Watch Deadlock's gameinfo.gi";
    Path.PathChanged = gameinfo;
    Install.WantedBy = [ "default.target" ];
  };
}
