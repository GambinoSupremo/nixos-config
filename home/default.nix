# Home-manager entry point for gav — external HM modules plus one
# submodule per concern. Applied to every host via hmModule in flake.nix.
{ inputs, ... }:

{
  imports = [
    # One concern per file (noctalia uses HM's native module; package pinned in dotfiles.nix)
    ./dotfiles.nix   # compositor plumbing, dotfile patching, activation scripts
    ./shell.nix      # fish, starship, fzf, zoxide, bat
    ./theming.nix    # gtk, cursor
    ./programs.nix   # git, neovim, obs, signal, pywalfox
    ./services.nix   # mullvad-gui systemd user service
    ./zen.nix        # Zen Browser — declarative profile, extensions, policies
    ./kineticwe.nix  # KineticWE binds, look and rules (seeded once at login)
  ];

  home.username      = "gav";
  home.homeDirectory = "/home/gav";
  home.stateVersion  = "26.05";
  programs.home-manager.enable = true;
}
