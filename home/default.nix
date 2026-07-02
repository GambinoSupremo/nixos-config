{ inputs, ... }:

{
  imports = [
    # External home-manager modules
    inputs.noctalia.homeModules.default       # programs.noctalia.*
    inputs.mangowm.hmModules.mango            # wayland.windowManager.mango.*
    inputs.plasma-manager.homeModules.plasma-manager  # programs.plasma.*
    # Sub-modules — one concern per file
    ./dotfiles.nix   # compositor plumbing, dotfile patching, activation scripts
    ./shell.nix      # fish, starship, fzf, zoxide, bat
    ./theming.nix    # gtk, cursor
    ./programs.nix   # git, neovim, obs, signal, pywalfox
    ./services.nix   # mullvad-gui systemd user service
    ./plasma.nix     # KDE plasma-manager config
  ];

  home.username      = "gav";
  home.homeDirectory = "/home/gav";
  home.stateVersion  = "26.05";
  programs.home-manager.enable = true;
}
