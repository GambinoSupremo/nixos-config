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

  # One wallpaper folder per theme.
  home.file."Pictures/themes".source = "${inputs.wallpapers}/themes";

  # Extra color templates (listed in noctalia/config.toml).
  xdg.configFile = {
    "noctalia/templates/cider.scss".source = ./noctalia/templates/cider.scss;
    "sh.cider.genten/themes/noctalia/theme.yml".source = ./noctalia/templates/cider-theme.yml;
  };

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
    # hypr/noctalia.lua has no template — seed an empty stub so hyprland.lua's
    # require("noctalia") loads before Noctalia's first run overwrites it.
    seedNoctalia ${pkgs.writeText "noctalia-lua-stub" ''
      -- Seeded by home-manager; Noctalia overwrites with theme colors.
    ''} ${config.xdg.configHome}/hypr/noctalia.lua

    seedNoctalia ${./noctalia/config.toml} ${config.xdg.configHome}/noctalia/config.toml
  '';
}
