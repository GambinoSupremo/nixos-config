# nixos-config

My NixOS flake for a Hyprland gaming desktop, with dotfiles pulled in from a
separate repo and patched for NixOS at build time.

<!-- Screenshot: once docs/screenshot.png exists (Hyprland + Noctalia bar on the
     AW3423DW ultrawide), uncomment the line below.
![Desktop screenshot](docs/screenshot.png)
-->

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

## Repo map

```
flake.nix                 # inputs + nixosConfigurations (desktop, vm)
nixos/
  base/                   # every host (default.nix lists them):
                          #   core (nix/locale/GC), users, networking
                          #   (+Mullvad), desktop (greeter, Hyprland, optional
                          #   Mango/Niri, portals, fonts), audio, services
                          #   (keyd, bluetooth, ...), packages, claude-code
  features/               # desktop PC extras:
    amd.nix               #   amdgpu/Mesa + Wayland env
    gaming.nix            #   Steam/gamescope/gamemode/novpn
    sunshine.nix          #   Moonlight host + virtual stream display
    tuning.nix            #   zram, ananicy, sysctls (borrowed from CachyOS)
    razer-white.nix       #   static white lighting for the Basilisk V4 Pro
  hosts/
    desktop/              # gavos: the physical machine
    vm/                   # nix-vm: build-only target
home/                     # home-manager for gav (shared by all hosts):
                          #   dotfiles.nix (dotfile patching/deployment, the
                          #   heart of the repo), shell, theming, programs
                          #   (incl. Zen), services, noctalia/, nixos-sync.sh
                          #   (the apply/update helper), plus small desktop-only
                          #   timers that log Steam, Plex, Kobo and Garmin data
                          #   into Obsidian and back up the NAS
                          #   claude-code.nix: MCP servers via HM's claude-code
                          #   module (mcp-nixos); settings.json stays hand-managed
docs/
  workflow.md             # rebuilding, apply/update, dotfiles, fresh install
  notes.md                # sessions, known constraints, not-in-nixpkgs list
  decisions.md            # judgment calls from the 2026-07 cleanup
.claude/CLAUDE.md         # instructions for Claude Code in this repo
```

## How I use it

Changes go on a `cleanup/*` branch, and `apply` lands it: it fast-forwards
`main`, pushes the dotfiles, refreshes their pin, switches, and pushes this
repo only if the build succeeded. Every couple of weeks `update` bumps all
inputs the same way. Dotfile edits only reach the system after they're pushed
and the pin is updated. The details are in [docs/workflow.md](docs/workflow.md),
and the hard-won gotchas are in [docs/notes.md](docs/notes.md).
