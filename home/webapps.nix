# Web apps: sites in their own Firefox window (no URL bar or tabs) via PWAsForFirefox,
# each with a launcher entry. Add a site with a fresh ULID; icons from dashboard-icons.
{ pkgs, ... }:

let
  icon =
    name: hash:
    pkgs.fetchurl {
      url = "https://raw.githubusercontent.com/homarr-labs/dashboard-icons/320c819da84048d5a3066e2578bfa83be9019fdf/png/${name}.png";
      inherit hash;
    };
in
{
  # Hide Firefox's own title bar (close/min/max); Hyprland doesn't need it.
  home.file.".local/share/firefoxpwa/profiles/01M5K68BBWCK8J79CEY7C3DDT9/user.js".text = ''
    user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
  '';
  home.file.".local/share/firefoxpwa/profiles/01M5K68BBWCK8J79CEY7C3DDT9/chrome/userChrome.css".text =
    ''
      #navigator-toolbox { visibility: collapse !important; }
    '';

  programs.firefoxpwa = {
    enable = true;
    # One shared profile, so web apps share logins with each other (not with Zen).
    profiles."01M5K68BBWCK8J79CEY7C3DDT9" = {
      name = "Web apps";
      sites."01M5K68BBWV98B2389D1RX2FW8" = {
        name = "Claude";
        url = "https://claude.ai";
        desktopEntry = {
          icon = icon "claude-ai" "sha256-76HQVfcmqUniwXKBC/E5DiaIdUMR0K3oVWA26HwSdfA=";
          categories = [ "Network" ];
        };
      };
    };
  };
}
