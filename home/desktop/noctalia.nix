# Noctalia: the bar, launcher and wallpapers. Its config files are copied in
# once and stay editable, so a rebuild never undoes what Noctalia changes.
{
  config,
  pkgs,
  lib,
  inputs,
  osConfig,
  ...
}:

let
  sessions = osConfig.gav.sessions;
in
{
  programs.noctalia = {
    enable = true;
    systemd.enable = true;
  };

  # Bar icons that only show while on (enabled in noctalia/config.toml).
  xdg.dataFile."noctalia/plugins/status".source = ./noctalia/plugins/status;

  # One wallpaper folder per theme.
  home.file."Pictures/themes".source = "${inputs.wallpapers}/themes";

  # --- First-run copies ---
  # Only copies a file that isn't there yet.
  home.activation.seedNoctaliaTemplates = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    seedNoctalia() {
      if [ ! -e "$2" ]; then
        run mkdir -p "$(dirname "$2")"
        run cp "$1" "$2"
        run chmod u+w "$2"
      fi
    }
    ${lib.optionalString sessions.mango "seedNoctalia ${inputs.dotfiles}/mango/noctalia.conf ${config.xdg.configHome}/mango/noctalia.conf"}
    ${lib.optionalString sessions.niri "seedNoctalia ${inputs.dotfiles}/niri/noctalia.kdl ${config.xdg.configHome}/niri/noctalia.kdl"}
    seedNoctalia ${inputs.dotfiles}/ghostty/themes/noctalia ${config.xdg.configHome}/ghostty/themes/noctalia
    # Empty placeholder so Hyprland's config loads before Noctalia's first run.
    seedNoctalia ${pkgs.writeText "noctalia-lua-stub" ''
      -- Seeded by home-manager; Noctalia overwrites with theme colors.
    ''} ${config.xdg.configHome}/hypr/noctalia.lua

    seedNoctalia ${./noctalia/config.toml} ${config.xdg.configHome}/noctalia/config.toml
  '';
}
