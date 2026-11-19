# Everything for my user (apps, desktop, scripts). One folder per topic,
# one file per thing. Add a new file here or it won't be used.
{ ... }:

{
  imports = [
    # desktop/ - Hyprland, the Noctalia bar and small desktop tools
    ./desktop/dotfiles.nix # copies my dotfiles repo into ~/.config
    ./desktop/noctalia.nix # the bar, launcher and wallpapers
    ./desktop/menu.nix # system menu + keybind cheatsheet
    ./desktop/capture-tools.nix # zoom, OCR, webcam bubble, recording fixes
    ./desktop/remind.nix # Super+Shift+R / `r`: Todoist reminders + PC pop-ups
    ./desktop/espanso.nix # type :smile: and get the emoji
    ./desktop/screensaver.nix # screensaver and idle timeouts
    ./desktop/dictation.nix # Super+D speech to text
    ./desktop/philips-input.nix # flip the Philips between this PC and the work Mac
    ./desktop/home-alerts.nix # homelab alerts as desktop notifications
    ./desktop/vpn-bluetooth.nix # Mullvad window at login, quieter Bluetooth

    # theming/ - colors, icons, cursor
    ./theming/gtk-cursor.nix # GTK theme, icons, cursor, Nautilus sidebar
    ./theming/theme.nix # `theme` command: palette + matching wallpapers
    ./theming/papirus.nix # folder icons follow the accent color
    ./theming/font.nix # `font` command: one coding font everywhere

    # apps/ - browser, web apps, default apps
    ./apps/zen.nix # Zen browser, search, privacy
    ./apps/webapps.nix # sites in their own window
    ./apps/programs.nix # what opens what, OBS, screenshots

    # terminal/ - shell, git, editor
    ./terminal/shell.nix # fish, aliases, apply/update commands (nixos-sync.sh)
    ./terminal/starship.nix # prompt
    ./terminal/git.nix # git and SSH
    ./terminal/editors.nix # Neovim

    # gaming/ - game fixes (Steam itself is in nixos/features/gaming.nix)
    ./gaming/battlenet.nix # Battle.net background sign-in, WoW launcher
    ./gaming/deadlock-fov.nix # keeps Deadlock's wide camera after updates
    ./gaming/vesktop-mic.nix # mutes Discord's mic during in-game push-to-talk

    # sync/ - backups and logs into the Obsidian vault
    ./sync/backup.nix # nightly NAS -> pCloud backup
    ./sync/daily-note.nix # where the daily notes live (used by game-log)
    ./sync/game-log.nix # Steam playtime into the daily note
    ./sync/kobo-sync.nix # Kobo reading log into Books notes
  ];

  home.stateVersion = "26.05";
}
