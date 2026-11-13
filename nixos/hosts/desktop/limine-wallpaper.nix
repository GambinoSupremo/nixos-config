# Boot menu wallpapers: every theme wallpaper, cropped to 21:9 and dimmed so the
# menu reads on bright ones. Limine picks one at random each boot.
{
  lib,
  runCommand,
  imagemagick,
  inputs,
}:

let
  src = "${inputs.wallpapers}/themes";
  isImage =
    n:
    lib.any (e: lib.hasSuffix e (lib.toLower n)) [
      ".jpg"
      ".jpeg"
      ".png"
    ];
  files = lib.concatMap (
    theme:
    map (f: "${theme}/${f}") (lib.filter isImage (lib.attrNames (builtins.readDir "${src}/${theme}")))
  ) (lib.attrNames (lib.filterAttrs (_: t: t == "directory") (builtins.readDir src)));
  # Keep the source extension in the name: some themes have foo.jpg and foo.png.
  outName = f: "${builtins.replaceStrings [ "/" ] [ "-" ] f}.jpg";
  dir = runCommand "limine-wallpapers" { nativeBuildInputs = [ imagemagick ]; } ''
    mkdir $out
    ${lib.concatMapStrings (f: ''
      magick ${lib.escapeShellArg "${src}/${f}"} \
        -resize 3440x1440^ -gravity center -extent 3440x1440 \
        -fill black -colorize 35% -quality 88 \
        $out/${lib.escapeShellArg (outName f)}
    '') files}
  '';
in
map (f: "${dir}/${outName f}") files
