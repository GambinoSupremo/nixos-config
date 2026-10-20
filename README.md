# nixos-config

NixOS flake for **gavos** (physical desktop) and a Proxmox **vm** testbed,
tracking nixos-unstable. Dotfiles come from the separate
[dotfiles](https://github.com/GambinoSupremo/dotfiles) repo as a GitHub flake
input, patched for NixOS at build time.

## Repo map

```
flake.nix                 # inputs + nixosConfigurations (desktop, vm)
nixos/
  base/                   # every host (default.nix lists them):
                          #   core (nix/locale/GC), users, networking
                          #   (+Mullvad), desktop (greeter, Hyprland, optional
                          #   Mango/Niri, portals, fonts), audio, services
                          #   (keyd, bluetooth, ...), packages
  features/               # desktop PC extras:
    amd.nix               #   amdgpu/Mesa + Wayland env
    gaming.nix            #   Steam/gamescope/gamemode/novpn
    sunshine.nix          #   Moonlight host + virtual stream display
    tuning.nix            #   zram, ananicy, sysctls (borrowed from CachyOS)
  hosts/
    desktop/              # gavos — physical machine
    vm/                   # Proxmox VM
home/                     # home-manager for gav (shared by all hosts):
                          #   dotfiles.nix (dotfile patching/deployment — the
                          #   heart of the repo), shell, theming, programs
                          #   (incl. Zen), services, noctalia/
```

## Sessions

Noctalia Greeter on greetd (`noctalia msg greeter-sync` copies the wallpaper,
colours and monitor layout to it). **Hyprland is the only
session by default.** Mango and Niri are off but kept: flip
`gav.sessions.mango` / `.niri` in nixos/base/desktop.nix to bring one
back (dotfiles deploy, Noctalia seeds and Sunshine follow). Mango mirrors
Hyprland's binds/rules and streams to Moonlight the same way; Niri gets the
ultrawide on Moonlight (no virtual output).
Noctalia v5 is the bar/shell, run as `noctalia.service` (upstream HM module).
KDE Plasma is not installed.

## Rebuild

```bash
apply     # land Claude's cleanup/* branches, push dotfiles, refresh the pin, switch, push
rebuild   # alias: sudo nixos-rebuild switch --flake ~/nixos-config#<host> (desktop or vm, set per host)
update    # update all inputs, switch, commit flake.lock, push
dotsync   # update only the dotfiles pin, switch, commit flake.lock, push
save      # build-check, then commit tracked changes as-is (no switch, no push)
```

`apply`, `update`, `dotsync` and `save` are fish wrappers around `nixos-sync`
(home/nixos-sync.sh, wired up in home/shell.nix). Switches go through `nh`
(build progress tree, then a package diff). Each run's raw output is kept in
`~/.cache/nixos-sync/last-<command>.log`, and the path is printed on failure. Each first makes sure ~/nixos-config is on an up-to-date
`main`: it switches to `main` only from a clean tree, then `git pull --ff-only`,
and stops with a message if either fails. `update` and `dotsync` also need a
clean tree. If the update or rebuild fails, flake.lock is restored and nothing
is committed; `update` retries once with Millennium held back first. On success
`update` commits **only flake.lock** ("flake: update inputs") and pushes, then
says if a reboot is needed (kernel or modules changed) and lists failed system
and user units.

`apply` is the one to run after Claude makes a change. In each repo it
fast-forwards `main` to the single `cleanup/*` branch that has commits `main`
lacks (it stops if there are several, or if the branch needs a rebase), then
pushes dotfiles, refreshes the dotfiles pin and switches. If the build fails it
resets nixos-config to where it was, so nothing is pushed. On success it pushes
nixos-config and deletes `cleanup/*` branches (local and on GitHub) that are
fully on `main`.

Dotfile edits are NOT live: the dotfiles input is lock-pinned to GitHub, so it
takes a push, then `nix flake update dotfiles` (or `update`) plus a rebuild to
deploy them. Unpushed edits: add `--override-input dotfiles path:$HOME/Projects/dotfiles`.

## Biweekly update ritual

1. `nix flake update --flake ~/nixos-config` (don't rebuild yet).
2. `git diff flake.lock` — note old→new revs for nixpkgs (niri, hyprland
   and noctalia all come from nixpkgs).
3. Release-note check for config-breaking changes: niri, hyprland,
   noctalia.
4. Migrate configs in the dotfiles repo if needed (respect the mustSed
   warnings in each file's header).
5. `rebuild` (or `update` if step 1 was skipped).
6. Validate:
   ```bash
   niri validate                       # parses ~/.config/niri/config.kdl
   hyprctl configerrors                # inside a Hyprland session
   systemctl --user status noctalia.service
   ls /run/current-system/sw/share/wayland-sessions   # 2 wayland sessions present
   ```

## Known constraints (load-bearing — do not rediscover these)

- **Monitor identity vs port names**: the DP-N index flips between boots
  (still happens on the RX 9070 XT). Niri and
  hypr/monitor.lua match by identity/EDID desc (never switch to port names).
- **VRR is off on the Alienware** (Hyprland `vrr = 0`). Its G-SYNC module and
  the RX 9070 XT don't get along: fullscreen VRR stuttered and flickered every
  game and logged amdgpu DMCUB errors. Monitor `vrr` changes only apply after
  Hyprland restarts (log out/in). Cap games at 175, the panel's refresh.
- **Colour / HDR**: the AW3423DW runs in its own Creator mode with the sRGB
  colour space (gamma 2.2), so it clamps to sRGB itself and the compositors
  send plain sRGB (`cm = "srgb"` in dotfiles hypr/monitor.lua). HDR is
  deliberately off until desktop HDR works with Moonlight/Sunshine streaming.
- **keyd edit keys**: Super+Z/X/C/V become Ctrl+Z / Shift+Delete /
  Ctrl+Insert / Shift+Insert (undo, cut, copy, paste) at the kernel level for
  ALL sessions (base/services.nix). keyd keeps any other held modifier, so
  Super+Shift+Z arrives as Ctrl+Shift+Z (redo) and no compositor bind on Super
  plus Z, X, C or V can ever fire. Ghostty maps Shift+Insert to clipboard paste
  and Shift+Delete to copy (dotfiles ghostty/config).
- **kvantum / qt.style**: setting HM `qt.style` (or installing kvantum
  system-wide) makes KDE's QML import "kvantum" and black-screens
  plasmashell. All compositors use `QT_QPA_PLATFORMTHEME=kde`. Re-test on
  Plasma major bumps.
- **Electron apps**: `NIXOS_OZONE_WL=1` (amd.nix) puts them on Wayland.
  Signal must launch with `--password-store=gnome-libsecret` everywhere or
  the keyring backend flips between sessions and loses the encryption key.
  tidal-hifi: never re-enable its gpuRasterization flag (GPU-process crash
  on Wayland; fix lives in ~/.config/tidal-hifi/config.json).
- **Mullvad**: the GUI user service polls the system daemon with a BOUNDED
  wait (home/services.nix) — an unbounded loop hung activation during
  rebuilds. `mullvad-exclude` is setuid and dies in Steam's nosuid sandbox;
  games that need to bypass the VPN use the `novpn` wrapper (daemon RPC,
  gaming.nix): `novpn gamemoderun %command%`.
- **mustSed coupling**: home/dotfiles.nix patches exact line text in the
  dotfiles repo. Rewording a matched line there fails this repo's build on
  purpose. Each patched dotfile carries a warning header.

## Fresh install

```bash
# Boot ISO, partition, mount at /mnt
nixos-generate-config --root /mnt   # copy values into nixos/hosts/<host>/hardware-configuration.nix
nixos-install --flake .#desktop     # or .#vm
# After first boot: mullvad account login; Zen: sign into Firefox Sync
# (install Keeper first — it holds the Sync password).
```

## Not in nixpkgs (checked during migration)

keeper-password-manager, lunatask, cider, millennium, moondeckbuddy,
opencode-bin, fluxer. Flatpak stays enabled as the escape hatch. The full
CachyOS→nixpkgs name-mapping tables from the migration live in git history
(README.md before 2026-07-14); the surviving decisions are inline comments
in nixos/base/packages.nix.
