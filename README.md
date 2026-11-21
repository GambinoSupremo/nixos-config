# nixos-config

My NixOS flake for a Hyprland gaming desktop, with dotfiles pulled in from a
separate repo and patched for NixOS at build time.

## Highlights

- **Dotfiles as a pinned input.** The [dotfiles](https://github.com/GambinoSupremo/dotfiles)
  repo is a GitHub flake input; `home/desktop/dotfiles.nix` deploys and patches it, and
  a patch whose source line changes fails the build instead of silently missing.
- **Hyprland with Noctalia.** Noctalia v5 is the bar, shell and greeter (on
  greetd). Mango and Niri are kept as one-flag alternative sessions.
- **Gaming on AMD.** Steam, gamescope and gamemode on an RX 9070 XT, a QD-OLED
  ultrawide, and a `novpn` wrapper so games can skip Mullvad.
- **Game streaming.** Sunshine streams to Moonlight through a virtual display
  sized for the client.
- **One-command upkeep.** `apply`, `update` and `dotsync` build and switch in one go;
  `apply` validates before publishing and keeps cleanup branches on failure.

## Hardware

| | |
|---|---|
| CPU | AMD Ryzen 7 7800X3D |
| GPU | AMD Radeon RX 9070 XT |
| Board / RAM | Gigabyte B650E AORUS ELITE X AX ICE, 32 GB DDR5-6000 |
| Storage | Samsung 980 PRO 2 TB, WD 1 TB HDD |
| Displays | Alienware AW3423DW (3440×1440, 175 Hz), Philips 278E1 (4K, 60 Hz) |

## Hosts

Both track nixos-unstable. `apply`, `update` and `dotsync` build and activate
only the host they run on.

- **desktop** (`gavos`): the machine above.
- **vm** (`nix-vm`): a build-only target. It evaluates the shared modules
  without the desktop's hardware (no GPU, Bluetooth or gaming) and is built
  when checking a change, not by `apply`.

## Layout

```
flake.nix            inputs (where everything is downloaded from) and the two hosts
nixos/               the system: needs root, same for every user
  base/              every host: users, network, audio, login screen, packages
  features/          desktop only: AMD GPU, gaming, Sunshine streaming, tuning
  hosts/             per machine: boot, kernel, disks
home/                my user: apps, desktop, scripts (default.nix lists them all)
  desktop/           dotfiles, Noctalia, system menu, screensaver, dictation
  theming/           GTK theme, cursor, palettes, folder icon colors
  apps/              Zen, web apps, default apps, OBS
  terminal/          fish, git, Neovim, the apply/update script
  gaming/            Battle.net sign-in, Deadlock camera, Discord mic
  sync/              NAS backup, game and Kobo logs into Obsidian
docs/                notes on why things are the way they are
```

## Where to edit

| Change | File |
|---|---|
| Inputs, checks, host definitions, formatter | `flake.nix` |
| Host control panel (monitors, feature switches), kernel, boot | `nixos/hosts/desktop/configuration.nix` |
| Custom `gav.*` option definitions | `nixos/base/options.nix` |
| Login screen, sessions, portals, fonts | `nixos/base/desktop.nix` |
| Installed applications | `nixos/base/packages.nix` |
| Keyboard remapping, Bluetooth, printer | `nixos/base/services.nix` |
| VPN and DNS | `nixos/base/networking.nix` |
| Steam and game launch wrappers | `nixos/features/gaming.nix` |
| Streaming and virtual display | `nixos/features/sunshine.nix` |
| GPU and system tuning | `nixos/features/amd.nix`, `tuning.nix` |
| Dotfile deployment | `home/desktop/dotfiles.nix` |
| Noctalia bar, first-run copies | `home/desktop/noctalia.nix` |
| Noctalia defaults for a new install | `home/desktop/noctalia/config.toml` |
| System menu, keybind cheatsheet | `home/desktop/menu.nix` |
| GTK, Qt, cursor, Nautilus sidebar | `home/theming/gtk-cursor.nix` |
| Themes (palette + wallpapers) | `home/theming/theme.nix`, `home/theming/palettes/` |
| Browser, search, privacy | `home/apps/zen.nix` |
| Web apps | `home/apps/webapps.nix` |
| Default apps, launchers, screenshots | `home/apps/programs.nix` |
| Shell aliases | `home/terminal/shell.nix` |
| Prompt | `home/terminal/starship.nix` |
| Git and SSH | `home/terminal/git.nix` |
| Neovim and editing tools | `home/terminal/editors.nix` |
| Battle.net and WoW launcher | `home/gaming/battlenet.nix` |
| Backup and activity logs | `home/sync/` |
| Rebuild workflow | `home/terminal/nixos-sync.sh`, [workflow](docs/workflow.md) |

`home/default.nix` and `nixos/base/default.nix` list the imported modules.
Compositor binds, rules, layouts and monitors live in `~/Projects/dotfiles`.
See [editing](docs/editing.md) for editor setup and validation commands,
and [notes](docs/notes.md) before changing hardware or session behavior.
[Performance](docs/performance.md) covers build concurrency, background work,
and how to compare gaming settings.

## How I use it

Changes go on a `cleanup/*` branch, and `apply` lands it: it fast-forwards
`main`, builds against the local dotfiles checkout, activates only after both
hosts build, then publishes dotfiles and refreshes the pin. Every couple of
weeks `update` bumps all inputs the same way. Dotfile edits only reach the system after they're pushed
and the pin is updated. The details are in [docs/workflow.md](docs/workflow.md),
and the hard-won gotchas are in [docs/notes.md](docs/notes.md).
