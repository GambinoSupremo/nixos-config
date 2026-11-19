# Zen Browser: search, privacy settings, and colors that follow the theme.
# Firefox Sync brings extensions, bookmarks and logins; this sets the rest.
# On a new machine install Keeper first, it holds the Sync password.
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ inputs.zen-browser.homeModules.beta ];

  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
    profiles.default = {
      # --- Search ---
      # Kagi only. Engines added by hand in Zen are wiped on rebuild.
      search = {
        force = true;
        default = "kagi";
        engines = {
          kagi = {
            name = "Kagi";
            urls = [
              { template = "https://kagi.com/search?q={searchTerms}"; }
              {
                template = "https://kagi.com/api/autosuggest?q={searchTerms}";
                type = "application/x-suggestions+json";
              }
            ];
            icon = "https://kagi.com/favicon.ico";
            definedAliases = [ "@k" ];
          };
        }
        # Hidden: the Kagi extension's duplicate and the built-ins.
        //
          lib.genAttrs
            [
              "search@kagi.comdefault"
              "google"
              "bing"
              "amazondotcom-us"
              "ebay"
              "perplexity"
            ]
            (_: {
              metaData.hidden = true;
            });
      };

      # --- Settings ---
      settings = {
        "zen.welcome-screen.seen" = true;
        "zen.window-sync.enabled" = false; # new windows don't copy my tabs

        # Needed for the theme colors.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "zen.theme.disable-lightweight" = false;
        # Load the unsigned page-colors add-on below.
        "xpinstall.signatures.required" = false;
        "extensions.autoDisableScopes" = 0;

        # Leave DNS to Mullvad; Zen's own DNS hangs Keeper's login on the VPN.
        "network.trr.mode" = 5;
        "doh-rollout.disable-heuristics" = true;

        # Privacy
        "browser.contentblocking.category" = "strict";
        "privacy.globalprivacycontrol.enabled" = true;
        "privacy.donottrackheader.enabled" = true;
        "dom.security.https_only_mode" = true;

        # Keeper fills logins and forms, not Zen.
        "signon.rememberSignons" = false;
        "browser.formfill.enable" = false;

        # No ads, Pocket, studies or default-browser nag.
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
        "extensions.pocket.enabled" = false;
        "app.shield.optoutstudies.enabled" = false;
        "browser.shell.checkDefaultBrowser" = false;
      };
    };
  };

  # --- Theme colors ---
  # zen-live.css carries the colors; add its import line to userChrome.css once.
  home.file.".config/zen/default/chrome/zen-live.css".source = ./zen-live.css;
  home.activation.zenLiveImport = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    chrome="${config.home.homeDirectory}/.config/zen/default/chrome/userChrome.css"
    if ! grep -qs 'zen-live.css' "$chrome"; then
      run mkdir -p "$(dirname "$chrome")"
      run sh -c "echo '@import \"zen-live.css\";' >> '$chrome'"
    fi
  '';

  # --- Launcher entry ---
  # Replaces the shipped one so the name doesn't say "(Beta)".
  xdg.desktopEntries.zen-beta = {
    name = "Zen Browser";
    genericName = "Web Browser";
    exec = "zen-beta --name zen-beta %U";
    icon = "${./zen.svg}";
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeType = [
      "text/html"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
    startupNotify = true;
    settings.StartupWMClass = "zen-beta";
    actions.new-private-window = {
      name = "New Private Window";
      exec = "zen-beta --private-window %U";
    };
  };

  # YouTube page colors follow the theme live; see page-colors/.
  home.file.".config/zen/default/extensions/page-colors@gavos.xpi".source =
    pkgs.callPackage ./page-colors { };

  # Pywalfox gets the colors from Noctalia's own host, which pushes every
  # theme change to all open browsers (Zen + web apps).
  home.file.".mozilla/native-messaging-hosts/pywalfox.json".text = builtins.toJSON {
    name = "pywalfox";
    description = "Noctalia Firefox theme native messaging host";
    path = lib.getExe config.programs.noctalia.package;
    type = "stdio";
    allowed_extensions = [ "pywalfox@frewacom.org" ];
  };
}
