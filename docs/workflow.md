# Workflow

## Rebuild

```bash
apply     # validate both hosts, switch, then publish landed cleanup branches
rebuild   # alias: sudo nixos-rebuild switch --flake ~/nixos-config#<host> (desktop or vm, set per host)
update    # update all inputs, validate both hosts, switch, commit flake.lock, push
dotsync   # update the dotfiles pin, validate both hosts, switch, commit and push
save      # build-check, then commit tracked changes as-is (no switch, no push)
```

`apply`, `update`, `dotsync` and `save` are fish wrappers around `nixos-sync`
(home/nixos-sync.sh, wired up in home/shell.nix). Switches go through `nh`
(build progress tree, then a package diff). Each run's raw output is kept in
`~/.cache/nixos-sync/last-<command>.log`, and the path is printed on failure.
Each first makes sure ~/nixos-config is on an up-to-date `main`: it switches to
`main` only from a clean tree, then `git pull --ff-only`, and stops with a
message if either fails. `update` and `dotsync` also need a clean tree. If the
update or rebuild fails, flake.lock is restored and nothing is committed.
On success `update`
commits **only flake.lock** ("flake: update inputs") and pushes, then says if a
reboot is needed (kernel or modules changed) and lists failed system and user
units.

`apply` is the one to run after committing a change on a cleanup branch. It
fast-forwards each repo's `main` to its single pending `cleanup/*` branch
(stopping if there are several or a rebase is needed), then builds desktop and
VM using the local dotfiles checkout. A failed build restores both local `main`
branches and keeps the cleanup branches. After a successful activation it
pushes dotfiles, refreshes the pin, commits and pushes `flake.lock`, then prunes
cleanup branches that are fully on `main`.

The helper is packaged in the active system generation. When changing
`home/nixos-sync.sh`, the first `apply` still runs the currently installed
version. Before that first run, check out the pending cleanup branches, build
both hosts with the local dotfiles checkout, then return both repos to clean
`main`:

```sh
nix build ~/nixos-config#nixosConfigurations.desktop.config.system.build.toplevel \
  --override-input dotfiles path:/home/gav/Projects/dotfiles --no-link
nix build ~/nixos-config#nixosConfigurations.vm.config.system.build.toplevel \
  --override-input dotfiles path:/home/gav/Projects/dotfiles --no-link
```

Later runs use the updated ordering.

## Dotfiles

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
   hyprctl configerrors                # inside a Hyprland session
   systemctl --user status noctalia.service
   niri validate                       # only if gav.sessions.niri is on
   # registered sessions: hyprland (+ mango/niri when enabled)
   ls "$(nix eval --raw ~/nixos-config#nixosConfigurations.desktop.config.services.displayManager.sessionData.desktops)/share/wayland-sessions"
   ```

## Fresh install

```bash
# Boot ISO, partition, mount at /mnt
nixos-generate-config --root /mnt   # copy values into nixos/hosts/desktop/hardware-configuration.nix
nixos-install --flake .#desktop
# After first boot: mullvad account login; Zen: sign into Firefox Sync
# (install Keeper first — it holds the Sync password).
```
