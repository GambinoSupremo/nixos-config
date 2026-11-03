# nixos-config

My NixOS flake for a Hyprland gaming desktop, with dotfiles pulled in from a
separate repo and patched for NixOS at build time.

## Highlights

- **Dotfiles as a pinned input.** The [dotfiles](https://github.com/GambinoSupremo/dotfiles)
  repo is a GitHub flake input; `home/dotfiles.nix` deploys and patches it, and
  a patch whose source line changes fails the build instead of silently missing.
- **Hyprland with Noctalia.** Noctalia v5 is the bar, shell and greeter (on
  greetd). Mango and Niri are kept as one-flag alternative sessions.
- **Gaming on AMD.** Steam, gamescope and gamemode on an RX 9070 XT, always-on
  HDR on a QD-OLED ultrawide, and a `novpn` wrapper so games can skip Mullvad.
- **Game streaming.** Sunshine streams to Moonlight through a virtual display
  sized for the client.
- **One-command upkeep.** `apply` and `update` build, switch, commit
  flake.lock and push, and roll back if the build fails.

## Hardware

| | |
|---|---|
| CPU | AMD Ryzen 7 7800X3D |
| GPU | AMD Radeon RX 9070 XT |
| Board / RAM | Gigabyte B650E AORUS ELITE X AX ICE, 32 GB DDR5-6000 |
| Storage | Samsung 980 PRO 2 TB, WD 1 TB HDD |
| Displays | Alienware AW3423DW (3440×1440, 175 Hz, HDR), Philips 278E1 (4K, 60 Hz) |

## Hosts

Both track nixos-unstable.

- **desktop** (`gavos`): the machine above.
- **vm** (`nix-vm`): a build-only target. It evaluates the shared modules
  without the desktop's hardware (no GPU, Bluetooth or gaming) and is built
  alongside desktop on every change.

## Where to edit

| Change | File |
|---|---|
| Inputs, host definitions, formatter | `flake.nix` |
| Kernel, boot, desktop hardware | `nixos/hosts/desktop/` |
| Login screen, sessions, portals, fonts | `nixos/base/desktop.nix` |
| Installed applications | `nixos/base/packages.nix` |
| Keyboard remapping, Bluetooth, printer | `nixos/base/services.nix` |
| VPN and DNS | `nixos/base/networking.nix` |
| Steam and game launch wrappers | `nixos/features/gaming.nix` |
| Streaming and virtual display | `nixos/features/sunshine.nix` |
| GPU and system tuning | `nixos/features/amd.nix`, `tuning.nix` |
| Browser, search, privacy | `home/zen.nix` |
| Git and SSH | `home/development.nix` |
| Neovim and editing tools | `home/editors.nix` |
| Default apps, launchers, screenshots | `home/programs.nix` |
| Shell aliases and prompt | `home/shell.nix` |
| Dotfile deployment and overview toggle | `home/dotfiles.nix` |
| GTK, Qt, cursor, live music themes | `home/theming.nix` |
| Noctalia defaults for a new install | `home/noctalia/config.toml` |
| Backup and activity logs | `home/backup.nix`, `home/*-log.nix`, `home/*-sync.nix` |
| Rebuild workflow | `home/nixos-sync.sh`, [workflow](docs/workflow.md) |

`home/default.nix` and `nixos/base/default.nix` list the imported modules.
Compositor binds, rules, layouts and monitors live in `~/Projects/dotfiles`.
See [editing](docs/editing.md) for editor setup and validation commands,
and [notes](docs/notes.md) before changing hardware or session behavior.

## How I use it

Changes go on a `cleanup/*` branch, and `apply` lands it: it fast-forwards
`main`, pushes the dotfiles, refreshes their pin, switches, and pushes this
repo only if the build succeeded. Every couple of weeks `update` bumps all
inputs the same way. Dotfile edits only reach the system after they're pushed
and the pin is updated. The details are in [docs/workflow.md](docs/workflow.md),
and the hard-won gotchas are in [docs/notes.md](docs/notes.md).
