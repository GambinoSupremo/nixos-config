# nixos-config

NixOS flake for gavos (desktop) and nix-vm (Proxmox test VM). Dotfiles come
from the separate dotfiles repo; see README.md for the repo map.

## Rules

- Commit messages and comments read like a person wrote them. Never add
  Co-Authored-By or any AI attribution.
- Work on a branch (`cleanup/<topic>`), one commit per logical change.
  Gavin merges with `--ff-only`.
- Never push this repo. Gavin pushes (his `update` helper pushes its own
  flake.lock commit).
- Never switch or test: no `nixos-rebuild switch/test`, no `sudo`, and don't
  run the fish helpers `rebuild`, `update`, `dotsync` or `save` (they switch,
  commit or push). Gavin does that. Their logic is the `nixos-sync` script in
  home/shell.nix.
- Do a read-only inventory first for anything big. Ask before anything
  irreversible (deleting files outside the repo, rewriting history, force).
- Use `rg`. In fish `grep` is aliased to `rg`; use `command grep` for GNU grep.
- Never edit `nvim/lua/plugins/dankcolors.lua` in the dotfiles repo
  (hand-curated, never regenerate).
- Monitors are matched by identity string (EDID description/model), never by
  port name. The NVIDIA DP-N numbering flips between boots.
- keyd owns Super+Z/X/C/V (undo/cut/copy/paste), including with Shift, Ctrl
  or Alt held. Never bind Super with Z, X, C or V in niri or Hyprland.
- The AW3423DW is in its own Creator/sRGB mode, so the compositors send plain
  sRGB (`cm = "srgb"`). HDR is deliberately off until desktop HDR works with
  Moonlight/Sunshine streaming. Don't turn it back on.

## Checking a change

- Build both hosts, every time:
  `nixos-rebuild build --flake .#desktop` and `nixos-rebuild build --flake .#vm`.
  Then `nix flake check`.
- Prove "no change" by comparing the system `drvPath` (or out path) before and
  after, or with `nix store diff-closures <old> <new>`. Empty diff-closures
  only means no package changed; compare hashes for text-only changes.
- Prove dotfiles changes with `diff -r` of the `dotfiles-patched` output
  (find it with `nix-store -qR <system> | rg dotfiles-patched$`).
- For `flake.lock` changes, confirm only the expected node changed.

## How the flake works

- The flake only sees git-tracked files. `git add` new files before building.
- Hosts are defined once via `mkHost` in flake.nix. It sets hostName and
  passes `host = { name, hostName, isVM }` to NixOS and home-manager. Use
  `host.isVM` / `host.hostName`; don't re-detect them.
- Flake output names (`desktop`, `vm`) differ from hostnames (`gavos`, `nix-vm`).
- `dotfiles` and `wallpapers` are `github:` inputs pinned in flake.lock.
  Dotfiles changes only land after they're pushed and
  `nix flake update dotfiles` is run. To test unpushed dotfiles, build with
  `--override-input dotfiles path:/home/gav/Projects/dotfiles`.
- home/dotfiles.nix copies niri/, hypr/ and ghostty/ from the dotfiles and
  adds NixOS-only bits. The two remaining `mustSed` calls (Hyprland session
  bootstrap in hypr/autostart.lua) fail the build if their source text
  changes, so change the dotfiles line and the patch together.
- Files Noctalia rewrites at runtime are seeded once as writable copies, not
  linked. Editing the repo copy doesn't change an existing live file.
- Formatting-only commits (nixfmt) go in `.git-blame-ignore-revs`.
