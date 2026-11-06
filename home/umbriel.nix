# Additional trial session; the existing default session stays in desktop.nix.
{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  umbriel = lib.getExe' osConfig.programs.umbriel.package "umbriel";
  # A stream.toml left by a crashed stream would pin games to SUNSHINE.
  bootstrap = pkgs.writeShellScript "umbriel-session-bootstrap" ''
    systemctl --user unset-environment HYPRLAND_INSTANCE_SIGNATURE MANGO_INSTANCE_SIGNATURE
    systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
    dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE
    if [ -e "$HOME/.config/umbriel/stream.toml" ]; then
      rm -f "$HOME/.config/umbriel/stream.toml"
      ${umbriel} msg config-reload
    fi
    systemctl --user reset-failed
    systemctl --user restart noctalia.service
    systemctl --user restart sunshine.service
  '';
in
{
  config = lib.mkIf osConfig.gav.sessions.umbriel {
    xdg.configFile."umbriel/config.toml".text =
      builtins.replaceStrings [ "@BOOTSTRAP@" ] [ "${bootstrap}" ]
        (builtins.readFile ./umbriel/config.toml);
    xdg.configFile."umbriel/games.toml".source = ./umbriel/games.toml;
  };
}
