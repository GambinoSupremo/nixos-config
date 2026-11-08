# Papirus folder colors follow the Noctalia accent. The store copy is read-only, so
# activation keeps a writable copy in ~/.local/share/icons; a Noctalia template hook recolors it.
{ pkgs, lib, ... }:

let
  icons = "${pkgs.papirus-icon-theme}/share/icons";

  papirus-accent = pkgs.writeShellApplication {
    name = "papirus-accent";
    runtimeInputs = [
      pkgs.papirus-folders
      pkgs.gtk3 # gtk-update-icon-cache
      pkgs.gawk
    ];
    text = ''
      # papirus-accent [#hex]: no arg = last accent (or Noctalia's template output).
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/papirus-accent"
      hex=''${1:-$(head -1 "$HOME/.cache/noctalia/papirus-accent" 2>/dev/null || cat "$state" 2>/dev/null || true)}
      hex=''${hex//[# ]/}
      [ ''${#hex} -ge 6 ] || exit 0
      [ -d "$HOME/.local/share/icons/Papirus-Dark" ] || exit 0

      # Nearest folder color by HSV distance; hue counts most, scaled by saturation.
      color=$(awk -v hex="''${hex:0:6}" '
        function hsv(x,  r,g,b,mx,mn,d,h) {
          r = strtonum("0x" substr(x,1,2))/255; g = strtonum("0x" substr(x,3,2))/255
          b = strtonum("0x" substr(x,5,2))/255
          mx = r; if (g > mx) mx = g; if (b > mx) mx = b
          mn = r; if (g < mn) mn = g; if (b < mn) mn = b
          d = mx - mn; h = 0
          if (d > 0) {
            if (mx == r) { h = (g - b) / d; if (h < 0) h += 6 }
            else if (mx == g) h = (b - r) / d + 2
            else h = (r - g) / d + 4
            h *= 60
          }
          H = h; S = (mx > 0) ? d / mx : 0; V = mx
        }
        BEGIN {
          n = split("adwaita:93c0ea black:4f4f4f blue:5294e2 bluegrey:607d8b breeze:57b8ec brown:ae8e6c carmine:a30002 cyan:00bcd4 darkcyan:45abb7 deeporange:eb6637 green:87b158 grey:8e8e8f indigo:5c6bc0 magenta:ca71df nordic:81a1c1 orange:ee923a palebrown:d1bfae paleorange:eeca8f pink:f06292 red:e25252 teal:16a085 violet:7e57c2 white:e4e4e4 yaru:676767 yellow:f9bd30", c)
          hsv(hex); th = H; ts = S; tv = V
          for (i = 1; i <= n; i++) {
            split(c[i], p, ":"); hsv(p[2])
            dh = th - H; if (dh < 0) dh = -dh; if (dh > 180) dh = 360 - dh; dh /= 180
            d = 10 * ts * S * dh * dh + (ts - S)^2 + 0.3 * (tv - V)^2
            if (best == "" || d < best) { best = d; name = p[1] }
          }
          print name
        }')

      mkdir -p "$(dirname "$state")"
      echo "#''${hex:0:6}" >"$state"
      [ "$(cat "$state.color" 2>/dev/null)" = "$color" ] && [ -z "''${PAPIRUS_FORCE:-}" ] && exit 0
      papirus-folders -t Papirus-Dark -C "$color" >/dev/null
      echo "$color" >"$state.color"
    '';
  };
in
{
  home.packages = [ papirus-accent ];

  xdg.configFile."noctalia/templates/papirus-accent".text = ''
    {{ colors.primary.default.hex }}
  '';

  # Refresh the writable copy only when the Papirus package changes, then reapply the color.
  home.activation.papirusWritable = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    dest="$HOME/.local/share/icons"
    if [ "$(readlink "$dest/.papirus-src" 2>/dev/null)" != "${icons}" ]; then
      run mkdir -p "$dest"
      for t in Papirus Papirus-Dark Papirus-Light; do
        run rm -rf "$dest/$t"
        run cp -a --reflink=auto "${icons}/$t" "$dest/"
        run chmod -R u+w "$dest/$t"
      done
      run ln -sfn "${icons}" "$dest/.papirus-src"
      run env PAPIRUS_FORCE=1 ${lib.getExe papirus-accent}
    fi
  '';
}
