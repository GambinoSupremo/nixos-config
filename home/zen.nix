# Zen Browser, search, privacy, and live Noctalia colors.
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:

{
  imports = [ inputs.zen-browser.homeModules.beta ];

  # ── Zen Browser ──────────────────────────────────────────────────────────────
  # Firefox Sync owns extensions, bookmarks and logins (fresh machine: install
  # Keeper first, it holds the Sync password). Nix sets what Sync doesn't carry.
  programs.zen-browser = {
    enable = true;
    setAsDefaultBrowser = true;
    profiles.default = {
      # force: HM owns search.json.mozlz4, so hand-added engines don't survive rebuilds.
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
        # The Kagi extension's duplicate engine plus built-ins we never use.
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

      settings = {
        "zen.welcome-screen.seen" = true;
        # Each window stands alone instead of mirroring tabs into new ones.
        "zen.window-sync.enabled" = false;
        # Noctalia theming: userChrome.css imports its colors, Pywalfox needs themes on.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        "zen.theme.disable-lightweight" = false;
        # Mullvad owns DNS; Zen's DoH stalls on-VPN and hangs Keeper's login.
        "network.trr.mode" = 5;
        "doh-rollout.disable-heuristics" = true;

        # Privacy: strict tracking protection, GPC + DNT, HTTPS-only.
        "browser.contentblocking.category" = "strict";
        "privacy.globalprivacycontrol.enabled" = true;
        "privacy.donottrackheader.enabled" = true;
        "dom.security.https_only_mode" = true;
        # Keeper fills logins and forms, not Zen.
        "signon.rememberSignons" = false;
        "browser.formfill.enable" = false;
        # No sponsored suggestions, Pocket, studies or default-browser nag.
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

  # Live Noctalia colors: zen-live.css maps Noctalia's Zen CSS onto Pywalfox's vars.
  # Noctalia rewrites userChrome.css but keeps extra lines, so append the import once.
  home.file.".config/zen/default/chrome/zen-live.css".source = ./noctalia/zen-live.css;
  home.activation.zenLiveImport = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    chrome="${config.home.homeDirectory}/.config/zen/default/chrome/userChrome.css"
    if ! grep -qs 'zen-live.css' "$chrome"; then
      run mkdir -p "$(dirname "$chrome")"
      run sh -c "echo '@import \"zen-live.css\";' >> '$chrome'"
    fi
  '';

  # Same id as the package's entry (~/.local/share wins), minus "(Beta)" in the name.
  xdg.desktopEntries.zen-beta = {
    name = "Zen Browser";
    genericName = "Web Browser";
    exec = "zen-beta --name zen-beta %U";
    icon = "${./icons/zen.svg}"; # Papirus's Zen icon, dark
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

  # Pywalfox's native host for Zen, without programs.firefox pulling in Firefox.
  home.file.".mozilla/native-messaging-hosts/pywalfox.json".text = builtins.toJSON {
    name = "pywalfox";
    description = "Pywalfox native app";
    path = "${pkgs.pywalfox-native}/bin/pywalfox";
    type = "stdio";
    allowed_extensions = [ "pywalfox@frewacom.org" ];
  };
}
