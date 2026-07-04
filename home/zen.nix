{ inputs, ... }:

# Zen Browser — declarative config via the zen-browser flake's home-manager
# module (programs.zen-browser mirrors home-manager's programs.firefox).
# This replaces the bare package that used to live in nixos/base/packages.nix;
# the module wraps and installs the same packages.default (zen-beta).
#
# Signing into the Mozilla account (Firefox Sync) stays manual — there is no
# declarative hook for it — but the profile in ~/.zen persists across rebuilds,
# so it's a once-per-machine step. Everything below applies on every machine.
{
  imports = [ inputs.zen-browser.homeModules.beta ];

  programs.zen-browser = {
    enable = true;

    # xdg-mime default handler for http(s)/html on every machine.
    setAsDefaultBrowser = true;

    policies = {
      # In-browser updates can't write to the read-only nix store; versions
      # come from the flake input (`nix flake update zen-browser`).
      DisableAppUpdate      = true;
      DisableTelemetry      = true;
      DisablePocket         = true;
      DisableFirefoxStudies = true;
      DontCheckDefaultBrowser = true;   # xdg-mime already handles this

      # Zen's built-in password manager is off — Keeper is the password
      # manager; the browser should never offer to save or fill logins.
      PasswordManagerEnabled = false;
      OfferToSaveLogins      = false;

      # Enhanced Tracking Protection, strict-equivalent. Locked=false so the
      # per-site shield toggle still works when a site breaks.
      EnableTrackingProtection = {
        Value         = true;
        Locked        = false;
        Cryptomining  = true;
        Fingerprinting = true;
      };

      # Most extensions come from Firefox Sync after signing in (settings
      # included) — declaring them here would fight Sync as a second source of
      # truth. Keeper is the exception: it holds the passwords needed to sign
      # into Sync in the first place, so it must exist before Sync does.
      # Todoist is declared only to get default_area pinning, which Sync
      # doesn't carry. default_area applies at install time — extensions
      # already installed by Sync won't be re-pinned retroactively.
      ExtensionSettings = let
        pinned = builtins.mapAttrs (guid: slug: {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
          installation_mode = "force_installed";
          default_area = "navbar";
        });
      in pinned {
        "KeeperFFStoreExtension@KeeperSecurityInc" = "keeper-password-manager";
        "support@todoist.com"                      = "todoist";
      };
    };

    profiles.default = {
      # prefs.js defaults — changeable in the browser, re-asserted on rebuild.
      # Zen-specific prefs are discoverable in about:config under "zen.".
      #
      # Privacy-focused defaults. Deliberately NOT enabled because they break
      # daily use: privacy.resistFingerprinting (kills dark-mode detection,
      # timezones, canvas) and disabling WebRTC (kills video calls).
      settings = {
        "zen.welcome-screen.seen" = true;  # skip onboarding on fresh machines

        # Each window is independent — don't mirror tabs/workspaces into new
        # windows (Zen's "window sync" duplicates the session otherwise).
        "zen.window-sync.enabled" = false;

        # Tracking protection: strict preset (pairs with the ETP policy above)
        "browser.contentblocking.category" = "strict";

        # Tell sites not to track/sell: Global Privacy Control + legacy DNT
        "privacy.globalprivacycontrol.enabled" = true;
        "privacy.donottrackheader.enabled"     = true;

        # HTTPS-Only mode (asks before falling back to http)
        "dom.security.https_only_mode" = true;

        # No sponsored/suggestion noise in the urlbar or new tab
        # (Tabliss owns the new tab anyway)
        "browser.urlbar.suggest.quicksuggest.sponsored"        = false;
        "browser.urlbar.suggest.quicksuggest.nonsponsored"     = false;
        "browser.newtabpage.activity-stream.showSponsored"     = false;
        "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

        # No form-history autofill — Keeper handles filling
        "browser.formfill.enable" = false;
      };
    };
  };
}
