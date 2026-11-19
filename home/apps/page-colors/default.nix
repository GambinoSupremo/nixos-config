# Unsigned add-on that recolors YouTube from the live browser theme (Zen + web apps).
{ runCommand, zip }:

runCommand "page-colors.xpi" { nativeBuildInputs = [ zip ]; } ''
  cp ${./manifest.json} manifest.json
  cp ${./background.js} background.js
  cp ${./youtube.js} youtube.js
  touch -d 2000-01-01 *
  zip -X -q $out manifest.json background.js youtube.js
''
