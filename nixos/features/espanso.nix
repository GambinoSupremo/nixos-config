# Text expansion: type a short code anywhere and it turns into text or an emoji.
# The codes live in home/desktop/espanso.nix.
{ pkgs, ... }:

{
  services.espanso = {
    enable = true;
    package = pkgs.espanso-wayland; # the module grants it keyboard access on Wayland
  };
}
