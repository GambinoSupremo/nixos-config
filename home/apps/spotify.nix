# Spotify with Noctalia's colors (community template spicetify-noctalia).
# Spicetify must patch Spotify's files, so it runs from a writable copy.
{
  config,
  pkgs,
  ...
}:

let
  inherit (pkgs) spotify;
  spicetify = "${pkgs.spicetify-cli}/bin/spicetify";
  copy = "${config.xdg.dataHome}/spotify-spicetify";
  ext = "${config.xdg.configHome}/spicetify/Extensions";

  # Nix's own launch script, pointed at the copy.
  copyWrapper = pkgs.runCommand "spotify-copy-wrapper" { } ''
    sed 's|${spotify}/share/spotify/.spotify-wrapped|${copy}/.spotify-wrapped|' \
      ${spotify}/share/spotify/spotify > $out
    grep -q '${copy}/.spotify-wrapped' $out
    chmod +x $out
  '';

  launcher = pkgs.writeShellScriptBin "spotify" ''
    src=${spotify}/share/spotify
    dst=${copy}
    # New Spotify build: fresh copy, then patch. Skipped while the old copy runs.
    if [ "$(cat "$dst/.nix-source" 2>/dev/null)" != "$src" ] && ! ${pkgs.procps}/bin/pgrep -f -- "$dst/" >/dev/null; then
      rm -rf "$dst.new"
      cp -r "$src" "$dst.new" && chmod -R u+w "$dst.new" \
        && install -m755 ${copyWrapper} "$dst.new/spotify" || exit 1
      rm -rf "$dst" && mv "$dst.new" "$dst"
      ${spicetify} config spotify_path "$dst" prefs_path "$HOME/.config/spotify/prefs" \
        current_theme Noctalia color_scheme Base replace_colors 1 inject_css 1 \
        check_spicetify_update 0 >/dev/null
      ${spicetify} -q clear backup apply --no-restart >/dev/null && echo "$src" > "$dst/.nix-source"
      # First run: let Noctalia add its colors before Spotify starts.
      if [ ! -e ${ext}/.noctalia-installed ]; then
        noctalia msg templates-apply >/dev/null 2>&1
        for _ in $(seq 30); do [ -e ${ext}/.noctalia-installed ] && break; sleep 0.5; done
      fi
    fi
    [ -x "$dst/spotify" ] || exec ${spotify}/bin/spotify "$@"
    exec "$dst/spotify" "$@"
  '';
in
{
  # Launcher first, so `spotify` (and the menu entry) runs the copy.
  home.packages = [
    (pkgs.symlinkJoin {
      name = "spotify-noctalia";
      paths = [
        launcher
        spotify
      ];
    })
    pkgs.spicetify-cli # the Noctalia template's hook calls it
  ];

  # Bare theme; Noctalia's extension sets the real colors live.
  xdg.configFile."spicetify/Themes/Noctalia/color.ini".text = ''
    [Base]
    text               = e6e1e5
    subtext            = cac4d0
    main               = 141218
    main-elevated      = 211f26
    highlight          = 2b2930
    highlight-elevated = 36343b
    sidebar            = 1d1b20
    player             = 1d1b20
    card               = 211f26
    shadow             = 000000
    selected-row       = e6e1e5
    button             = d0bcff
    button-active      = e0d2ff
    button-disabled    = 938f99
    tab-active         = 2b2930
    notification       = efb8c8
    notification-error = f2b8b5
    misc               = 49454f
  '';
  xdg.configFile."spicetify/Themes/Noctalia/user.css".text = "/* colors only */\n";
}
