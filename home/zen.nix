{
  inputs,
  config,
  lib,
  ...
}:

# Zen Browser via the zen-browser flake's HM module (mirrors programs.firefox).
# Firefox Sync sign-in stays manual (once per machine; ~/.zen persists).
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  programs.zen-browser = {
    enable = true;

    # xdg-mime default handler for http(s)/html on every machine.
    setAsDefaultBrowser = true;

    policies = {
      # In-browser updates can't write to the read-only nix store; versions
      # come from the flake input (`nix flake update zen-browser`).
      DisableAppUpdate = true;
      DisableTelemetry = true;
      DisablePocket = true;
      DisableFirefoxStudies = true;
      DontCheckDefaultBrowser = true; # xdg-mime already handles this

      # Zen's built-in password manager is off — Keeper is the password
      # manager; the browser should never offer to save or fill logins.
      PasswordManagerEnabled = false;
      OfferToSaveLogins = false;

      # Enhanced Tracking Protection, strict-equivalent. Locked=false so the
      # per-site shield toggle still works when a site breaks.
      EnableTrackingProtection = {
        Value = true;
        Locked = false;
        Cryptomining = true;
        Fingerprinting = true;
      };

      # No force-installed extensions — Sync owns them. Fresh machine: install
      # Keeper manually first (it holds the Sync password), then sign into Sync.
    };

    profiles.default = {
      # Kagi declared here so it's default before Sync installs anything. force:
      # HM owns search.json.mozlz4 — hand-added engines won't survive rebuilds.
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

          # The Kagi extension registers its own engine; hide the duplicate
          # picker entry (extension features unaffected).
          "search@kagi.comdefault".metaData.hidden = true;

          # Built-in engines we never want offered (ids from the live
          # search.json.mozlz4; ddg and wikipedia stay visible).
          google.metaData.hidden = true;
          bing.metaData.hidden = true;
          "amazondotcom-us".metaData.hidden = true;
          ebay.metaData.hidden = true;
          perplexity.metaData.hidden = true;
        };
      };

      # prefs.js defaults, re-asserted on rebuild. resistFingerprinting and
      # WebRTC-off deliberately NOT set — they break dark mode / video calls.
      settings = {
        "zen.welcome-screen.seen" = true; # skip onboarding on fresh machines

        # Load chrome/userChrome.css — Noctalia's zen-browser template @imports its colors there.
        "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
        # Zen ignores extension themes by default; Pywalfox's live colors need this off.
        "zen.theme.disable-lightweight" = false;

        # Each window is independent — don't mirror tabs/workspaces into new
        # windows (Zen's "window sync" duplicates the session otherwise).
        "zen.window-sync.enabled" = false;

        # Tracking protection: strict preset (pairs with the ETP policy above)
        "browser.contentblocking.category" = "strict";

        # Tell sites not to track/sell: Global Privacy Control + legacy DNT
        "privacy.globalprivacycontrol.enabled" = true;
        "privacy.donottrackheader.enabled" = true;

        # HTTPS-Only mode (asks before falling back to http)
        "dom.security.https_only_mode" = true;

        # No sponsored/suggestion noise in the urlbar or new tab
        # (Tabliss owns the new tab anyway)
        "browser.urlbar.suggest.quicksuggest.sponsored" = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
        "browser.newtabpage.activity-stream.showSponsored" = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

        # No form-history autofill — Keeper handles filling
        "browser.formfill.enable" = false;

        # Let Mullvad own DNS. Zen's built-in DoH to Cloudflare is blocked
        # on-VPN, so lookups stall then fall back — Keeper's login hangs.
        "network.trr.mode" = 5;
        "doh-rollout.disable-heuristics" = true;
      };
    };
  };

  # Live Noctalia colors: zen-live.css maps Noctalia's Zen CSS onto Pywalfox's theme vars.
  # Noctalia's apply.sh rewrites userChrome.css but keeps extra lines, so append the import once.
  home.file.".config/zen/default/chrome/zen-live.css".source = ./noctalia/zen-live.css;
  home.activation.zenLiveImport = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    chrome="${config.home.homeDirectory}/.config/zen/default/chrome/userChrome.css"
    if ! grep -qs 'zen-live.css' "$chrome"; then
      run mkdir -p "$(dirname "$chrome")"
      run sh -c "echo '@import \"zen-live.css\";' >> '$chrome'"
    fi
  '';

  # Same id as the package's entry (~/.local/share wins), minus the "(Beta)" name.
  xdg.desktopEntries.zen-beta = {
    name = "Zen Browser";
    genericName = "Web Browser";
    exec = "zen-beta --name zen-beta %U";
    icon = "zen-browser";
    categories = [
      "Network"
      "WebBrowser"
    ];
    mimeType = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "application/vnd.mozilla.xul+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
    startupNotify = true;
    settings.StartupWMClass = "zen-beta";
    actions = {
      new-window = {
        name = "New Window";
        exec = "zen-beta --new-window %U";
      };
      new-private-window = {
        name = "New Private Window";
        exec = "zen-beta --private-window %U";
      };
      profile-manager-window = {
        name = "Profile Manager";
        exec = "zen-beta --ProfileManager";
      };
    };
  };
}
