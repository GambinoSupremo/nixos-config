# Web apps: sites in their own window with no tabs or URL bar, each with a
# launcher entry. Add one from System menu → Setup → Add web app (saves it to
# webapps.json, then apply), or copy a site block below with a new ID (ULID).
{
  inputs,
  lib,
  pkgs,
  ...
}:

let
  profile = ".local/share/firefoxpwa/profiles/01M5K68BBWCK8J79CEY7C3DDT9";
  addons = (inputs.firefox-addons.overlays.default pkgs pkgs).firefox-addons;

  # Sites added from the menu.
  added = lib.listToAttrs (
    map (s: lib.nameValuePair s.id { inherit (s) name url; }) (lib.importJSON ./webapps.json)
  );

  # Asks for a URL + name, commits it to webapps.json ready for apply.
  webapp-add = pkgs.writeShellApplication {
    name = "webapp-add";
    runtimeInputs = [
      pkgs.git
      pkgs.jq
      pkgs.zenity
      pkgs.wl-clipboard
      pkgs.libnotify
    ];
    text = ''
      repo=$HOME/nixos-config
      file=home/apps/webapps.json
      clip=$(wl-paste -n 2>/dev/null || true)
      [[ $clip == http*://* ]] || clip=""
      url=$(zenity --entry --title="Add web app" --text="Site address" --entry-text="$clip" --width=420) || exit 0
      [ -n "$url" ] || exit 0
      [[ $url == http*://* ]] || url=https://$url
      host=''${url#*://}; host=''${host%%/*}; host=''${host#www.}
      name=$(zenity --entry --title="Add web app" --text="Name" --entry-text="''${host%.*}") || exit 0
      [ -n "$name" ] || exit 0

      # ULID: 10 time chars + 16 random, Crockford base32.
      alpha=0123456789ABCDEFGHJKMNPQRSTVWXYZ
      ms=$(date +%s%3N) id=""
      for _ in 1 2 3 4 5 6 7 8 9 10; do id=''${alpha:ms%32:1}$id; ms=$((ms / 32)); done
      rand=$(head -c 512 /dev/urandom | LC_ALL=C tr -dc "$alpha")
      id=$id''${rand:0:16}

      cd "$repo"
      if [ -n "$(git status --porcelain)" ]; then
        notify-send -a "Web apps" "nixos-config has unsaved changes" "Run apply (or clear them) first, then try again."
        exit 1
      fi
      # Same rule as apply: reuse the one waiting cleanup branch, else start one.
      start=$(git branch --show-current) branch=""
      for b in $(git for-each-ref --format='%(refname:short)' refs/heads/cleanup/); do
        [[ "$(git cherry main "$b")" == *+* ]] && branch=$b
      done
      if [ -n "$branch" ]; then git switch -q "$branch"; else git switch -q -c "cleanup/webapps-$(date +%m%d-%H%M)" main; fi
      jq --arg id "$id" --arg n "$name" --arg u "$url" '. + [{id: $id, name: $n, url: $u}]' "$file" >"$file.new"
      mv "$file.new" "$file"
      git commit -q -m "webapps: add $name" -- "$file"
      git switch -q "$start"

      if zenity --question --title="Add web app" --text="$name saved. Run apply now to install it?"; then
        exec ghostty --gtk-single-instance=false --class=com.ghostty.floating \
          -e fish -c "apply; read -P 'Done. Enter to close '"
      fi
      notify-send -a "Web apps" "$name saved" "Installs on the next apply."
    '';
  };

  # --- Extensions ---
  # Pulled from the firefox-addons flake input; bumped by `update`.
  extensions = [
    addons.sponsorblock
    addons.enhancer-for-youtube
    addons.darkreader
    # Window colors follow the theme live (host set up in zen.nix).
    addons.pywalfox
  ];
in
{
  home.file =
    builtins.listToAttrs (
      map (
        pkg:
        lib.nameValuePair "${profile}/extensions/${pkg.addonId}.xpi" {
          source = "${pkg}/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/${pkg.addonId}.xpi";
        }
      ) extensions
    )
    // {
      # YouTube page colors follow the theme live; see page-colors/.
      "${profile}/extensions/page-colors@gavos.xpi".source = pkgs.callPackage ./page-colors { };
      # Turn the extensions on and keep them at these versions.
      "${profile}/user.js".text = ''
        user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
        user_pref("extensions.autoDisableScopes", 0);
        user_pref("extensions.update.enabled", false);
        user_pref("xpinstall.signatures.required", false);
      '';
      # The toolbar hides above the window; mouse to the top edge brings it back.
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

  # Hide the plain "firefoxpwa" launcher; it only opens an empty browser.
  xdg.dataFile."applications/firefoxpwa.desktop" = {
    force = true;
    text = "[Desktop Entry]\nHidden=true\n";
  };

  # --- Sites ---
  programs.firefoxpwa = {
    enable = true;
    # Firefox ESR runtime: plain Firefox won't load the unsigned page-colors add-on.
    package = pkgs.wrapFirefox (pkgs.firefoxpwa-unwrapped.override {
      firefoxRuntime = pkgs.firefox-esr-unwrapped;
    }) { };
    # One profile, so the web apps share logins with each other (not with Zen).
    profiles."01M5K68BBWCK8J79CEY7C3DDT9" = lib.mkMerge [
      { sites = added; }
      {
      name = "Web apps";
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
      }
    ];
  };

  home.packages = [ webapp-add ];
}
