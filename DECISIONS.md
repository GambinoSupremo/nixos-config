# Cleanup decisions — 2026-07-14

Judgment calls from the deep-cleanup pass. Pairs with dotfiles/DECISIONS.md.

## Changed
- commonOverlay removed: verified by full desktop build with overlays=[]
  (eval + build, current lock). Resurrect from git history if an input
  update reintroduces qt6ct/noto-fonts-emoji/fish-stub references.
- systemPackages single-ownership: dropped starship/bat/fzf/zoxide (HM) and
  mullvad-vpn (module installs it — verified in nixpkgs module source).
  Root/TTY fallback set kept: git, neovim (+fish via users.nix). eza stays
  system-wide because HM only aliases it.
- mullvad-gui ExecStartPre: unbounded daemon poll → 30s bounded, then start
  anyway (user units can't After= system units; unbounded loop hung
  activation during rebuild switches).
- btrfs-assistant removed (snapper runtime dep; native btrfs covers it).
- mango VRR: generated monitor.conf vrr:1 → vrr:0 + vrr_only_fullscreen:1
  on steam_app_ in dotfiles rule.conf. NOT vrr:2 — mango clamps monitor vrr
  to 0/1 (parse_config.h); 2 would have silently meant always-on, the
  flicker case.
- hypr signal-desktop sed dropped from dotfiles.nix (bind removed upstream;
  the sed would otherwise fail the build against new dotfiles).
- Seed empty ~/.config/hypr/noctalia.lua stub — fresh machine's
  require("noctalia") failed until Noctalia's first run.
- arkenfox-update alias ported from zsh dotfiles with corrected path
  (~/.config/zen/default). INERT: no updater.sh installed, and user.js is a
  read-only HM symlink (zen.nix settings). arkenfox vs declarative prefs is
  an unresolved either/or — decide before first use.
- README rewritten; CachyOS mapping tables dropped (git history has them).
- Comment corrections: theming.nix (kvantum claim was false — everything
  uses QT_QPA_PLATFORMTHEME=kde), desktop.nix (hyprland-session.target
  alone never started noctalia reliably; the bootstrap script does),
  dotfiles.nix /etc/nixos reference.

## Left alone
- laptop host + amd.nix + nixos-hardware input: intentional unwired spare
  (per README); zero lock cost since nixos-hardware follows nixpkgs.
- fish double-registration (system programs.fish + HM): system side is
  login-shell registration; both needed.
- packages.nix "was X" Arch-provenance comments: kept — README tables were
  dropped, so these are now the only in-repo record.
- pywalfox-native in systemPackages: kept for the CLI; the HM native-host
  json references the store path directly and doesn't need it.
- defaultSession = "hyprland" despite Mango being the daily driver — as
  found; deliberate choice, not cleanup material.
- /etc/nixos pre-flake leftovers: since removed (empty as of 2026-10-01).

## 2026-08-03
- niri libdisplay-info overlay removed: pin existed 2026-07-28 to
  2026-08-03, dropped once nixpkgs shipped niri built against
  libdisplay-info-sys >= 0.4.
- mullvad-vpn.package unset + gui.enable = true: same nixpkgs bump split
  the daemon out of pkgs.mullvad-vpn.

## 2026-08-05
- Steam VPN bypass: chose Option A (wrap Steam's launcher binary to call
  `mullvad split-tunnel add $$` + exec — same RPC mechanism gaming.nix's
  `novpn` already uses) over per-game opt-in or desktop-entry-only wrapping.
  Confirmed split-tunnel enforcement is PID/cgroup-based via daemon RPC, not
  path-based — nixpkgs' mullvad-vpn is just the vendored .deb (no in-tree
  source to grep), so this came from the existing `novpn` behavior + the
  services.mullvad-vpn module (security.wrappers.mullvad-exclude), not
  Mullvad source. No persistent state to manage: the daemon's exclusion set
  is in-memory/PID-based and resets per boot, so the wrapper script IS the
  declarative artifact — nothing store-hash-keyed to go stale.
  Trade-off accepted: ALL Steam traffic (client + every game) now bypasses
  Mullvad unconditionally; retires the per-game `novpn %command%` launch
  option workaround from Rivals 2. New file: nixos/features/steam-novpn.nix,
  imported in hosts/desktop/configuration.nix next to gaming.nix.
  NEVER IMPLEMENTED (as of 2026-10-01): steam-novpn.nix doesn't exist;
  per-game `novpn` launch options are still the live mechanism.

## 2026-10-01
- MangoWM HM plumbing removed from home/dotfiles.nix (bootstrap script,
  mustSeds, generated monitor.conf, 255-char check, deploy + noctalia seed).
  Session was already disabled 2026-09-24; mango edits in the dotfiles repo
  can no longer break this build.
- electron-40.10.5 permittedInsecurePackages + insecure-pin-check removed:
  nothing in the closure uses electron 40. The check never fired because
  tidal-hifi is unfree and it evaluated without allowing unfree.

## 2026-10-08
- Kernel: CachyOS (nix-cachyos-kernel) → nixpkgs linuxPackages_zen. Its only
  binary cache (attic.xuyh0120.win, the author's personal server) is IPv6-only,
  and Mullvad runs with IPv6 off, so every build stalled on lookups and kernel
  bumps would have compiled locally. The CachyOS tuning (zram, ananicy rules,
  sysctls in features/cachyos.nix) doesn't need that input and stays.
- Mac-style edit keys: keyd [meta] now also maps z = C-z and x = S-delete.
  Compositor binds on Super+Z/X/C/V moved or removed in the dotfiles.
- noctalia: dropped the noctalia flake input, its cachix cache and our two
  patches (bar-capsule-blur, history-click-focus). The patched build could
  never be cached, so every noctalia change meant a local compile.
  home-manager's programs.noctalia now uses nixpkgs' noctalia (cache.nixos.org,
  follows releases).

## 2026-10-09
- Mango back as a session, from nixpkgs (programs.mango, 0.17.5) instead of the
  old mangowm flake input. systemd.packages links its mango-session.target.
  The dotfiles mango/ was brought in line with Hyprland (binds, rules,
  monitors, tags); home/dotfiles.nix deploys it with one mustSed (bootstrap).
- Sunshine on Mango: create_virtual_output SUNSHINE + wlr-randr mode, then
  tagmon the Steam windows onto it (tags are per monitor, so there's no
  workspace to lend). monitor.conf's SUNSHINE rule makes it the X11 primary;
  the mode survives reload_config. destroy_all_virtual_output strands windows
  still on it (they come back only if SUNSHINE is recreated), so stop moves
  them off first. The script picks Hyprland/Mango from XDG_CURRENT_DESKTOP.
- Mango and Niri off by default (2026-10-09) behind gav.sessions.{mango,niri}.
  Mango streamed ~55 fps vs 120 on Hyprland, and Hyprland got per-monitor
  workspaces + layouts, so neither is needed day to day. Turned on, the build
  matches the old always-on one (dotfiles-patched identical).

## Unsure / watch
- Mango session + Sunshine flow tested only against a headless Mango
  (2026-10-09); first real login/stream not yet verified.
- keyd passthrough claim (SUPER+CTRL+V works, plain SUPER+C/V consumed) is
  reasoned from keyd semantics + observed behavior, not live-tested yet.
  WRONG (2026-10-08, from keyd 2.6.0 source): a [meta] binding drops only
  Super and keeps other held modifiers, so SUPER+CTRL+V became Ctrl+Shift+Insert.
- Hyprland fresh-boot fallback path (broken lua → hyprland.conf) untested.
- flake.lock path-input lastModified for dotfiles looks stale even when
  content is current — narHash is what matters; don't trust the date.
  MOOT since 2026-10-07: dotfiles is a github: input (locked by rev).
