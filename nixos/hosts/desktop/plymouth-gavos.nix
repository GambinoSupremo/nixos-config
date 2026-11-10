# Plymouth theme "gavos": figlet logo (same as the screensaver) + ASCII bouncer.
# Images are rendered at build time; the script only fades, bounces and blinks.
{
  runCommand,
  figlet,
  imagemagick,
  nerd-fonts,
}:

let
  font = "${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNLNerdFontMono-Regular.ttf";
  logoColor = "#e0e0e0";
  dimColor = "#707070";
in
runCommand "plymouth-theme-gavos"
  {
    nativeBuildInputs = [
      figlet
      imagemagick
    ];
  }
  ''
    export HOME=$TMPDIR XDG_CACHE_HOME=$TMPDIR
    d=$out/share/plymouth/themes/gavos
    mkdir -p $d

    text() { # text <file> <color> <size> <out.png>
      magick -background none -fill "$2" -font ${font} -pointsize "$3" "label:@$1" "$4"
    }

    figlet -f slant gavos >logo.txt
    text logo.txt '${logoColor}' 36 logo.png
    magick logo.png -trim +repage $d/logo.png

    # Bouncer: "<=>" sliding along a 24-cell track, there and back (42 frames).
    w=24; seq=$(seq 0 21; seq 20 -1 1); i=0
    for p in $seq; do
      printf '[%s<=>%s]' "$(printf '%*s' $p "" | tr ' ' .)" \
        "$(printf '%*s' $((w - 3 - p)) "" | tr ' ' .)" >bar.txt
      text bar.txt '${dimColor}' 24 $d/bar-$i.png
      i=$((i + 1))
    done

    for m in boot:booting shutdown:shutting\ down reboot:rebooting; do
      printf '%s_' "''${m#*:}" >on.txt; printf '%s ' "''${m#*:}" >off.txt
      text on.txt '${dimColor}' 24 $d/status-''${m%%:*}-on.png
      text off.txt '${dimColor}' 24 $d/status-''${m%%:*}-off.png
    done

    cp ${./plymouth-gavos.script} $d/gavos.script
    cat >$d/gavos.plymouth <<EOF
    [Plymouth Theme]
    Name=gavos
    Description=figlet gavos with an ASCII bouncer
    ModuleName=script

    [script]
    ImageDir=$d
    ScriptFile=$d/gavos.script
    EOF
  ''
