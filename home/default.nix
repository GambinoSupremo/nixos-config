# Home-manager entry point for gav — external HM modules plus one
# submodule per concern. Applied to every host via hmModule in flake.nix.
{ ... }:

{
  imports = [
    # One concern per file (noctalia: HM's native module with nixpkgs' package)
    ./umbriel.nix
    ./dotfiles.nix # compositor plumbing, dotfile patching, activation scripts
    ./shell.nix # fish, starship, fzf, zoxide, bat
    ./theming.nix # gtk, cursor
    ./zen.nix # browser, search, privacy, live colors
    ./development.nix # git and SSH
    ./editors.nix # Neovim and shared editing tools
    ./programs.nix # default apps, launchers, OBS, screenshots
    ./services.nix # mullvad-gui user service
    ./backup.nix # nightly encrypted NAS Personal → pCloud backup (desktop)
    ./daily-note.nix # gav.dailyNote: daily note folder + path pattern for the loggers below
    ./plex-log.nix # Plex webhooks → Obsidian Movies/TV notes (desktop)
    ./kobo-sync.nix # kobo-sync: Kobo reading log → Obsidian Books notes (desktop)
    ./garmin-sync.nix # garmin-sync: Garmin steps/sleep/workouts → Obsidian daily notes (desktop)
    ./game-log.nix # game-log: Steam playtime → Obsidian daily notes (desktop)
    ./vesktop-mic.nix # vesktop-mic: mute Discord's mic stream during in-game push-to-talk
    ./philips-input.nix # philips-input: switch the Philips between Linux and the work Mac
    ./webapps.nix # app-like Firefox windows (PWAsForFirefox)
    ./menu.nix # sysmenu + keybinds: system menu and bind cheatsheet in Noctalia
    ./theme.nix # theme: named looks (palette + matching wallpapers)
    ./papirus.nix # Papirus folder colors follow the accent
    ./dictation.nix # voxtype: Super+D speech-to-text (desktop)
    ./screensaver.nix # screensaver + Noctalia idle timeouts
    ./deadlock-fov.nix # re-adds r_aspectratio when gameinfo.gi gets rewritten (desktop)
  ];

  home.stateVersion = "26.05";
}
