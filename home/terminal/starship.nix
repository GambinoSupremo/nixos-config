# Starship prompt. Noctalia edits starship.toml to recolor it, so the file has
# to stay writable: each rebuild lays down my layout and keeps Noctalia's colors.
{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

{
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    # false loads it last, so nothing else can replace the prompt.
    enableInteractive = false;
  };

  home.activation.starshipConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    (
    PATH=${
      lib.makeBinPath (
        with pkgs;
        [
          coreutils
          gnugrep
          gnused
          gawk
          diffutils
        ]
      )
    }:$PATH
    starshipSrc=${inputs.dotfiles}/starship/starship.toml
    starshipDst=${config.xdg.configHome}/starship.toml
    starshipMb="# >>> NOCTALIA STARSHIP PALETTE >>>"
    starshipMe="# <<< NOCTALIA STARSHIP PALETTE <<<"
    starshipTmp=$(mktemp)
    starshipBlk=$(mktemp)
    awk -v mb="$starshipMb" -v me="$starshipMe" \
      '$0 == mb {skip=1} !skip {print} $0 == me {skip=0}' \
      "$starshipSrc" > "$starshipTmp"
    if [ -f "$starshipDst" ] && grep -qF "$starshipMb" "$starshipDst"; then
      starshipBlkSrc=$starshipDst
    else
      starshipBlkSrc=$starshipSrc
    fi
    awk -v mb="$starshipMb" -v me="$starshipMe" \
      '$0 == mb {keep=1} keep {print} $0 == me {keep=0}' \
      "$starshipBlkSrc" > "$starshipBlk"
    if [ -s "$starshipBlk" ]; then
      echo "" >> "$starshipTmp"
      cat "$starshipBlk" >> "$starshipTmp"
    fi
    if ! cmp -s "$starshipTmp" "$starshipDst" 2>/dev/null; then
      run install -m644 "$starshipTmp" "$starshipDst"
    fi
    rm -f "$starshipTmp" "$starshipBlk"
    )
  '';
}
