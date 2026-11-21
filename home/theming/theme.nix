# The `theme` command: each theme is a color palette plus a wallpaper folder
# in ~/Pictures/themes. The list is theme-list.nix; modules can hook changes.
{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  themeList = import ./theme-list.nix;
  themeSlugs = map (t: lib.removePrefix "themes/" t.dir) (
    builtins.filter (t: t.dir != "themes") themeList
  );
  paletteFiles = builtins.attrNames (builtins.readDir ./palettes);
  missingPalettes = map (t: t.palette) (
    builtins.filter (
      t: t.source == "custom" && !(builtins.elem "${t.palette}.json" paletteFiles)
    ) themeList
  );

  themeHooksFile = pkgs.writeText "theme-hooks.sh" (
    lib.concatStringsSep "\n" (
      lib.mapAttrsToList (name: body: ''
        # hook: ${name}
        (
          ${body}
        ) 9>&-
      '') config.gav.hooks.onThemeChange
    )
  );

  # First wallpaper of each theme folder, cropped to a rounded square.
  thumbs = pkgs.runCommand "theme-thumbs" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    mkdir -p $out
    for dir in ${inputs.wallpapers}/themes/*/; do
      img=$(find "$dir" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.png' -o -iname '*.webp' \) | sort | head -1)
      [ -n "$img" ] || continue
      magick "$img" -resize 128x128^ -gravity center -extent 128x128 \
        \( -size 128x128 xc:none -fill white -draw 'roundrectangle 0,0 127,127 26,26' \) \
        -compose DstIn -composite "$out/$(basename "$dir").png"
    done
  '';

  theme = pkgs.writeShellApplication {
    name = "theme";
    runtimeInputs = [
      pkgs.libnotify
      pkgs.util-linux # flock
    ];
    runtimeEnv = {
      THEMES_LIST = lib.concatMapStringsSep "\n" (
        t: "${t.name}|${t.mode}|${t.source}|${t.palette}|${t.dir}"
      ) themeList;
      THEME_THUMBS = "${thumbs}";
      THEME_HOOKS_FILE = "${themeHooksFile}";
    };
    text = builtins.readFile ./scripts/theme.sh;
  };

  theme-install = pkgs.writeShellApplication {
    name = "theme-install";
    runtimeInputs = [
      pkgs.git
      pkgs.python3
      pkgs.imagemagick
      pkgs.zenity
      pkgs.wl-clipboard
      pkgs.libnotify
    ];
    runtimeEnv.THEME_PALETTE_PY = "${./theme-palette.py}";
    text = builtins.readFile ./scripts/theme-install.sh;
  };

  wallpaper-check = pkgs.writeShellApplication {
    name = "wallpaper-check";
    runtimeInputs = [ pkgs.imagemagick ];
    text = builtins.readFile ./scripts/wallpaper-check.sh;
  };
in
{
  options.gav.hooks.onThemeChange = lib.mkOption {
    description = "Shell hooks run after `theme` switches (THEME_NAME, THEME_MODE, THEME_SOURCE, THEME_PALETTE, THEME_DIR).";
    type = lib.types.attrsOf lib.types.lines;
    default = { };
  };

  config = {
    assertions = [
      {
        assertion = missingPalettes == [ ];
        message = "theme-list.nix references missing custom palettes: ${lib.concatStringsSep ", " missingPalettes}";
      }
    ];

    # Login screen follows too, once the new wallpaper has landed.
    gav.hooks.onThemeChange.greeter = ''
      (sleep 3; noctalia msg greeter-sync >/dev/null 2>&1) &
    '';

    home.packages = [
      theme
      theme-install
      wallpaper-check
    ];

    # Keep one staging subfolder per theme in ~/Pictures/wallpaper-inbox.
    home.activation.wallpaperInbox = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      for slug in ${lib.escapeShellArgs themeSlugs}; do
        run mkdir -p "$HOME/Pictures/wallpaper-inbox/$slug"
      done
    '';

    # Custom palettes for the "custom" source.
    xdg.configFile = builtins.listToAttrs (
      map (f: {
        name = "noctalia/palettes/${f}";
        value.source = ./palettes + "/${f}";
      }) paletteFiles
    );
  };
}
