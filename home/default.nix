# Home-manager entry point for gav — external HM modules plus one
# submodule per concern. Applied to every host via hmModule in flake.nix.
{ ... }:

{
  imports = [
    # One concern per file (noctalia: HM's native module with nixpkgs' package)
    ./dotfiles.nix # compositor plumbing, dotfile patching, activation scripts
    ./shell.nix # fish, starship, fzf, zoxide, bat
    ./theming.nix # gtk, cursor
    ./programs.nix # zen, git, neovim, obs, satty, signal, vesktop
    ./services.nix # mullvad-gui + noctalia-game-toasts user services
    ./backup.nix # nightly encrypted NAS Personal → pCloud backup (desktop)
    ./plex-log.nix # Plex webhooks → Obsidian Movies/TV notes (desktop)
    ./kobo-sync.nix # kobo-sync: Kobo reading log → Obsidian Books notes (desktop)
  ];

  home.username = "gav";
  home.homeDirectory = "/home/gav";
  home.stateVersion = "26.05";
  programs.home-manager.enable = true;
}
