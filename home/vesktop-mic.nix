# vesktop-mic mute|unmute: silences only Vesktop's copy of the mic, so in-game
# voice still hears you. Hyprland holds it muted while push-to-talk is down.
{ pkgs, ... }:

let
  vesktop-mic = pkgs.writeShellApplication {
    name = "vesktop-mic";
    runtimeInputs = [
      pkgs.pipewire
      pkgs.wireplumber
      pkgs.jq
    ];
    text = ''
      case "''${1:-}" in
        mute) m=1 ;;
        unmute) m=0 ;;
        *) echo "usage: vesktop-mic mute|unmute" >&2; exit 1 ;;
      esac
      pw-dump | jq -r '.[] | .info.props? // {}
        | select(."media.class" == "Stream/Input/Audio" and ."node.name" == "vesktop")
        | ."object.id"' | while read -r id; do wpctl set-mute "$id" "$m"; done
    '';
  };
in
{
  home.packages = [ vesktop-mic ];
}
