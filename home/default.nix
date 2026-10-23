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
    ./services.nix # mullvad-gui user service
    ./backup.nix # nightly encrypted NAS Personal → pCloud backup (desktop)
    ./plex-log.nix # Plex webhooks → Obsidian Movies/TV notes (desktop)
    ./kobo-sync.nix # kobo-sync: Kobo reading log → Obsidian Books notes (desktop)
    ./garmin-sync.nix # garmin-sync: Garmin steps/sleep/workouts → Obsidian daily notes (desktop)
    ./game-log.nix # game-log: Steam playtime → Obsidian daily notes (desktop)
    ./vesktop-mic.nix # vesktop-mic: mute Discord's mic stream during in-game push-to-talk
    ./webapps.nix # Claude etc. as app-like Firefox windows (PWAsForFirefox)
  ];

  home.stateVersion = "26.05";
}
