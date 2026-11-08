# philips-input: flips the Philips 278E1 between DisplayPort (Linux) and HDMI-1 (work Mac).
# --skip-ddc-checks cuts each ddcutil call from about 6 s to 0.2 s.
{ pkgs, ... }:

let
  philips-input = pkgs.writeShellApplication {
    name = "philips-input";
    runtimeInputs = [ pkgs.ddcutil ];
    text = ''
      ddc() { ddcutil --model "PHL 278E1" --skip-ddc-checks "$@"; }
      case "$(ddc --brief getvcp 60)" in
        *x0f) ddc setvcp 60 0x11 ;;
        *x11) ddc setvcp 60 0x0f ;;
        *) echo "philips-input: couldn't read the current input" >&2; exit 1 ;;
      esac
    '';
  };
in
{
  home.packages = [ philips-input ];
}
