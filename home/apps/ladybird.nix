# Ladybird: the same search and privacy choices as Zen (zen.nix).
# Ladybird rewrites Settings.json itself, so apply merges these keys in.
{
  config,
  pkgs,
  lib,
  ...
}:

let
  forced = {
    firstRunComplete = true;

    # Kagi with suggestions, like Zen.
    searchEngine = {
      engine = "Kagi";
      suggestions = true;
    };

    # Leave DNS to Mullvad, like Zen.
    dnsSettings.mode = "system";

    # Privacy: GPC on; tracker + ad lists stand in for Zen's strict blocking.
    globalPrivacyControl = true;
    contentBlockers = {
      enabled = true;
      builtInLists = {
        easyList = true;
        easyPrivacy = true;
      };
    };
    backgroundNetworking = {
      enabled = true;
      features.contentBlockerSubscriptionUpdates = true;
    };

    # Zen's look: bookmarks bar, tabs down the left, colors from the theme.
    appearance = {
      showBookmarksBar = "always";
      interfaceTheme = "system";
      websiteColorScheme = "system";
    };
    tabs = {
      verticalTabsEnabled = true;
      verticalTabsPosition = "left";
    };
  };
in
{
  home.activation.ladybirdSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    f="${config.xdg.configHome}/Ladybird/Profiles/default/Settings.json"
    run mkdir -p "$(dirname "$f")"
    tmp="$(mktemp)"
    if { [ -s "$f" ] && cat "$f" || echo '{}'; } \
        | ${lib.getExe pkgs.jq} --argjson forced ${lib.escapeShellArg (builtins.toJSON forced)} \
        '. * $forced' > "$tmp"; then
      run mv "$tmp" "$f"
    else
      rm -f "$tmp"
      echo "ladybird: Settings.json is not valid JSON, left alone" >&2
    fi
  '';
}
