# Web apps: sites in their own Firefox window (no URL bar or tabs) via PWAsForFirefox,
# each with a launcher entry. Add a site with a fresh ULID; icons are Papirus names so
# they match the rest of the launcher (Claude's is drawn in home/icons/).
{ lib, pkgs, ... }:

let
  profile = ".local/share/firefoxpwa/profiles/01M5K68BBWCK8J79CEY7C3DDT9";

  # Signed XPIs from addons.mozilla.org, pinned (Firefox's auto-update is off below).
  extensions = {
    "sponsorBlocker@ajay.app" = {
      url = "https://addons.mozilla.org/firefox/downloads/file/4897574/sponsorblock-6.1.7.xpi";
      sha256 = "0d50e1632c6f15ee15a543e670e1c572974605a5c02622916e08e026803df83f";
    };
    "enhancerforyoutube@maximerf.addons.mozilla.org" = {
      url = "https://addons.mozilla.org/firefox/downloads/file/4933627/enhancer_for_youtube-2.0.136.xpi";
      sha256 = "38a0420804d08224fc44e838aec432e947eb688b1300f423eeecbb44d33037fa";
    };
    "addon@darkreader.org" = {
      url = "https://addons.mozilla.org/firefox/downloads/file/5055786/darkreader-4.9.133.xpi";
      sha256 = "eb06c5096d761616c7f1d954c11524ca4bff4fe7229044dc1fce288a8c0853ab";
    };
  };
in
{
  home.file =
    lib.mapAttrs' (
      id: src: lib.nameValuePair "${profile}/extensions/${id}.xpi" { source = pkgs.fetchurl src; }
    ) extensions
    // {
      # Allow userChrome.css (toolbar below).
      # Extensions dropped into the profile load enabled, and stay at the pinned versions.
      "${profile}/user.js".text = ''
        user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
        user_pref("extensions.autoDisableScopes", 0);
        user_pref("extensions.update.enabled", false);
      '';
      # Toolbar hides above the window; mouse at the top edge slides it over the page,
      # and it stays while an extension popup or menu from it is open.
      "${profile}/chrome/userChrome.css".text = ''
        #navigator-toolbox {
          position: fixed !important;
          top: 0; left: 0; right: 0;
          z-index: 10 !important;
          transform: translateY(calc(-100% + 3px));
          transition: transform 120ms ease !important;
        }
        #navigator-toolbox:hover,
        #navigator-toolbox:focus-within,
        #navigator-toolbox:has([open="true"]) {
          transform: none;
        }
      '';
    };

  # The package's own "firefoxpwa" entry just opens the bare runtime browser.
  xdg.dataFile."applications/firefoxpwa.desktop" = {
    force = true;
    text = "[Desktop Entry]\nHidden=true\n";
  };

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
