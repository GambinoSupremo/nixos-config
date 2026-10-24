# Notes

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

## Known constraints (load-bearing — do not rediscover these)

- **Monitor identity vs port names**: the DP-N index flips between boots
  (still happens on the RX 9070 XT). Niri and
  hypr/monitor.lua match by identity/EDID desc (never switch to port names).
- **VRR is off on the Alienware** (Hyprland `vrr = 0`). Its G-SYNC module and
  the RX 9070 XT don't get along: fullscreen VRR stuttered and flickered every
  game and logged amdgpu DMCUB errors. Monitor `vrr` changes only apply after
  Hyprland restarts (log out/in). Cap games at 175, the panel's refresh.
- **Colour / HDR**: the AW3423DW runs always-on HDR (`cm = "hdr"`,
  `sdrbrightness = 2.0` in dotfiles hypr/monitor.lua; monitor in HDR 400 True
  Black). No auto-HDR switching, since SDR/HDR mode switches blank the screen.
  HDR games need `PROTON_ENABLE_WAYLAND=1 PROTON_ENABLE_HDR=1`.
- **keyd edit keys**: Super+Z/X/C/V become Ctrl+Z / Shift+Delete /
  Ctrl+Insert / Shift+Insert (undo, cut, copy, paste) at the kernel level for
  ALL sessions (base/services.nix). keyd keeps any other held modifier, so
  Super+Shift+Z arrives as Ctrl+Shift+Z (redo) and no compositor bind on Super
  plus Z, X, C or V can ever fire. Ghostty maps Shift+Insert to clipboard paste
  and Shift+Delete to copy (dotfiles ghostty/config).
- **kvantum / qt.style**: HM `qt.style` and a system-wide kvantum stay off.
  When Plasma was installed, they made KDE's QML import "kvantum" and
  black-screened plasmashell. Plasma is gone now, but `qt.style` would still
  force `QT_STYLE_OVERRIDE` on every session. All compositors set
  `QT_QPA_PLATFORMTHEME=qt6ct`, so Qt 6 apps get the Noctalia palette from
  qt6ct.conf (home/theming.nix).
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

## Not in nixpkgs (checked during migration)

keeper-password-manager, lunatask, moondeckbuddy, opencode-bin, fluxer.
Since then cider arrived as `cider-2` (Millennium was added via its own flake
input, then dropped 2026-10-24). Flatpak stays enabled as the escape hatch. The full
CachyOS→nixpkgs name-mapping tables from the migration live in git history
(README.md before 2026-07-14); the surviving decisions are inline comments
in nixos/base/packages.nix.
