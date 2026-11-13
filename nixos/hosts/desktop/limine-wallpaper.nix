# Boot menu wallpaper: Eldritch island, cropped to 21:9 and dimmed so the menu reads.
{
  runCommand,
  imagemagick,
  inputs,
}:

runCommand "limine-wallpaper.jpg" { nativeBuildInputs = [ imagemagick ]; } ''
  magick ${inputs.wallpapers}/themes/eldritch/a_video_game_screen_of_a_video_game.jpg \
    -resize 3440x1440^ -gravity center -extent 3440x1440 \
    -fill black -colorize 25% -quality 90 $out
''
