{ ... }:
{
  imports = [
    ./desktop/dotfiles.nix
    ./terminal/shell.nix
    ./look/gtk-cursor.nix
    ./apps/zen.nix
    ./terminal/git.nix
    ./terminal/editors.nix
    ./apps/programs.nix
    ./desktop/vpn-bluetooth.nix
    ./gaming/battlenet.nix
    ./sync/backup.nix
    ./sync/daily-note.nix
    ./sync/kobo-sync.nix
    ./sync/game-log.nix
    ./gaming/vesktop-mic.nix
    ./desktop/philips-input.nix
    ./apps/webapps.nix
    ./desktop/menu.nix
    ./look/theme.nix
    ./look/papirus.nix
    ./desktop/dictation.nix
    ./desktop/screensaver.nix
    ./gaming/deadlock-fov.nix
    ./desktop/home-alerts.nix
  ];
  home.stateVersion = "26.05";
}
