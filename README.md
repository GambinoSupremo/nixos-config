# nixos-config

NixOS flake for **gavos** (physical desktop) and a Proxmox **vm** testbed,
tracking nixos-unstable. Dotfiles come from the separate
[dotfiles](https://github.com/GambinoSupremo/dotfiles) repo as a path flake
input, patched for NixOS at build time.

## Repo map

```
flake.nix                 # inputs + nixosConfigurations (desktop, vm)
nixos/
  base/                   # imported by every host: core (locale/nix/GC),
                          # users, networking (+mullvad daemon), audio
                          # (pipewire), services (keyd, bluetooth, ...),
                          # packages (systemPackages)
  features/               # opt-in per host:
    desktop.nix           #   SDDM + Mango/Niri/Hyprland sessions + portals + fonts
    nvidia.nix            #   driver pin + Wayland env (desktop host)
    amd.nix               #   laptop-only GPU config
    gaming.nix            #   Steam/gamescope/gamemode/novpn
    sunshine.nix          #   Moonlight host + virtual stream display
  hosts/
    desktop/              # gavos — physical machine
    vm/                   # Proxmox VM
    laptop/               # spare AMD laptop; NOT wired into flake outputs
home/                     # home-manager for gav (shared by all hosts):
                          #   dotfiles.nix (dotfile patching/deployment — the
                          #   heart of the repo), shell, theming, programs,
                          #   services, plasma, zen, noctalia/config.toml
```

## Sessions

SDDM (SilentSDDM, X11 greeter) with four sessions. **Mango is the daily
driver**, Niri secondary, Hyprland tertiary/HDR (and the configured
`defaultSession`), KDE Plasma 6 for the full-DE fallback. Noctalia v5 is the
bar/shell everywhere, run as `noctalia.service` (upstream HM module).

## Rebuild

```bash
rebuild   # alias: sudo nixos-rebuild switch --flake ~/nixos-config#desktop
update    # alias: nix flake update + rebuild — a bare `nix flake update`
          # only rewrites the lock; nothing lands until the rebuild
```

Dotfile edits are NOT live: the dotfiles input is lock-pinned, so it takes
`nix flake update dotfiles` (or `update`) plus a rebuild to deploy them.

## Biweekly update ritual

1. `nix flake update --flake ~/nixos-config` (don't rebuild yet).
2. `git diff flake.lock` — note old→new revs for mangowm, noctalia, and
   nixpkgs (niri + hyprland come from nixpkgs).
3. Release-note check for config-breaking changes: mango wiki/commits,
   niri release notes, hyprland release notes, noctalia releases.
4. Migrate configs in the dotfiles repo if needed (respect the mustSed
   warnings in each file's header).
5. `rebuild` (or `update` if step 1 was skipped).
6. Validate:
   ```bash
   niri validate                       # parses ~/.config/niri/config.kdl
   hyprctl configerrors                # inside a Hyprland session
   mango -c ~/.config/mango/config.conf 2>&1 | head   # nested; parse errors on stderr, Ctrl+C out
   systemctl --user status noctalia.service
   ls /run/current-system/sw/share/wayland-sessions   # 3 wayland sessions present
   ```

## Known constraints (load-bearing — do not rediscover these)

- **Mango 255-char parser limit**: mango's config parser truncates values at
  255 chars (`char value[256]` in parse_config.h). home/dotfiles.nix rejects
  long lines at build time; keep mango config lines short. This is why the
  session bootstrap is a script, not an inline one-liner.
- **Monitor identity vs port names**: the NVIDIA DP-N index flips with GPU
  probe order (DP-1/DP-2 vs DP-3/DP-4 both seen). Niri uses identity strings
  (never switch to port names); mango's generated monitor.conf lists both
  names; mango tag/rule.conf and hypr configs match DP-2/DP-1 only and
  degrade silently if the names flip.
- **NVIDIA driver pin**: 610 branch (`nvidiaPackages.latest`), open modules.
  The 595 branch intermittently scanned the AW3423DW into a corner. Move
  back to `.stable` once stable ≥ 610 (details in nixos/features/nvidia.nix).
- **NVIDIA cursor bug**: hardware cursors freeze under the HDR/10-bit
  pipeline. Hyprland: `no_hardware_cursors = true` + `min_refresh_rate = 60`
  (software cursors render no frames on an idle VRR screen otherwise).
  Mango: `WLR_NO_HARDWARE_CURSORS=1` in env.conf.
- **VRR / gamma flicker**: fluctuating refresh causes visible gamma flicker
  on the QD-OLED desktop. Policy everywhere is fullscreen-games-only VRR:
  Hyprland `vrr = 2`, niri `on-demand=true` + steam_app rule, mango
  monitorrule `vrr:0` + `vrr_only_fullscreen:1` on steam_app_ (mango has no
  mode 2; monitor vrr is clamped to 0/1).
- **HDR**: lives in dotfiles hypr/monitor.lua only (cm=hdr, 10-bit).
  MangoWM master has no working HDR on the scenefx/GLES renderer.
- **keyd clipboard**: super+c/super+v are remapped to Ctrl-/Shift-Insert at
  the kernel level for ALL sessions (base/services.nix). Compositor binds on
  plain SUPER+C/V can never fire; binds with extra keys/modifiers
  (SUPER+X, SUPER+CTRL+V) pass through keyd untouched.
- **wlroots NVIDIA env vars** (`GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`,
  `WLR_NO_HARDWARE_CURSORS`) are scoped per-compositor and must NEVER go
  into global sessionVariables — they black-screen KWin.
- **kvantum / qt.style**: setting HM `qt.style` (or installing kvantum
  system-wide) makes KDE's QML import "kvantum" and black-screens
  plasmashell. All compositors use `QT_QPA_PLATFORMTHEME=kde`. Re-test on
  Plasma major bumps.
- **Electron apps**: `NIXOS_OZONE_WL=1` (nvidia.nix) puts them on Wayland.
  Signal must launch with `--password-store=gnome-libsecret` everywhere or
  the keyring backend flips between sessions and loses the encryption key.
  tidal-hifi: never re-enable its gpuRasterization flag (GPU-process crash
  on NVIDIA+Wayland; fix lives in ~/.config/tidal-hifi/config.json).
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
