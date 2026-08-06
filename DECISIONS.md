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
- /etc/nixos/{configuration.nix,configuration.nix.save,
  hardware-configuration.nix}: stale pre-flake leftovers, NOT removed
  (needs sudo): sudo rm /etc/nixos/configuration.nix{,.save} /etc/nixos/hardware-configuration.nix

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
  Implementation pending (see chat skeleton).

## Unsure / watch
- keyd passthrough claim (SUPER+CTRL+V works, plain SUPER+C/V consumed) is
  reasoned from keyd semantics + observed behavior, not live-tested yet.
- mango vrr_only_fullscreen behavior verified in source/docs, not on-screen
  — confirm no desktop flicker and working game VRR after next mango boot.
- Hyprland fresh-boot fallback path (broken lua → hyprland.conf) untested.
- flake.lock path-input lastModified for dotfiles looks stale even when
  content is current — narHash is what matters; don't trust the date.
