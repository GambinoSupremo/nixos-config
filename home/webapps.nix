# Web apps: sites in their own Firefox window (no URL bar or tabs) via PWAsForFirefox,
# each with a launcher entry. Add a site with a fresh ULID; icons are Papirus names so
# they match the rest of the launcher (Claude's is drawn in home/icons/).
{ ... }:

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
          icon = "${./icons/claude.svg}";
          categories = [ "Network" ];
        };
      };
      sites."01M5K770R4RKNSG5FN1DWH0N2M" = {
        name = "Todoist";
        url = "https://app.todoist.com";
        desktopEntry = {
          icon = "todoist";
          categories = [ "Office" ];
        };
      };
      sites."01M5K7BCQEJQ4BGRNA0T8WVXPA" = {
        name = "YouTube";
        url = "https://www.youtube.com";
        desktopEntry = {
          icon = "youtube";
          categories = [
            "AudioVideo"
            "Video"
          ];
        };
      };
      sites."01M5K770R4K7SGG8XNF738Q2AD" = {
        name = "Proton Mail";
        url = "https://mail.proton.me";
        desktopEntry = {
          icon = "proton-mail";
          categories = [
            "Network"
            "Email"
          ];
        };
      };
    };
  };
}
