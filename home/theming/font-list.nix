# Coding fonts for the `font` picker. Installed by nixos/base/desktop.nix;
# to add one: name, fontconfig family (`fc-list : family`) and package.
pkgs: with pkgs.nerd-fonts; [
  {
    name = "JetBrains Mono";
    family = "JetBrainsMono Nerd Font";
    package = jetbrains-mono;
  }
  {
    name = "Cascadia Mono";
    family = "CaskaydiaMono Nerd Font";
    package = caskaydia-mono;
  }
  {
    name = "Fira Code";
    family = "FiraCode Nerd Font";
    package = fira-code;
  }
  {
    name = "Iosevka";
    family = "IosevkaTerm Nerd Font";
    package = iosevka-term;
  }
  {
    name = "Geist Mono";
    family = "GeistMono Nerd Font";
    package = geist-mono;
  }
  {
    name = "Commit Mono";
    family = "CommitMono Nerd Font";
    package = commit-mono;
  }
  {
    name = "Victor Mono";
    family = "VictorMono Nerd Font";
    package = victor-mono;
  }
  {
    name = "Hack";
    family = "Hack Nerd Font";
    package = hack;
  }
  {
    name = "Meslo";
    family = "MesloLGM Nerd Font";
    package = meslo-lg;
  }
  {
    name = "Bitstream Vera";
    family = "BitstromWera Nerd Font";
    package = bitstream-vera-sans-mono;
  }
  {
    name = "Departure Mono";
    family = "DepartureMono Nerd Font";
    package = departure-mono;
  }
]
