# Editing the config

Open `~/nixos-config` as a folder in Neovim (`nvim .`) or Zed. Start with
the README's file map; `home/default.nix` lists the home-manager modules.
Use `desktop` for the physical machine's flake output; `gavos` is its hostname.

## Editors

Both editors use `nil` for Nix diagnostics and navigation, and `nixfmt` for
formatting. NixOS installs these tools; there is no second Nix server to
install through Mason. The formatter version follows `flake.lock`.

- **Neovim:** `~/Projects/dotfiles/nvim/lua/plugins/nix.lua` configures Nix
  support. LazyVim's normal format-on-save behavior applies. Run `:LspInfo`
  to check the server or `:ConformInfo` to check formatting.
- **Zed:** install the Nix extension once. `.zed/settings.json` selects
  `nil` and `nixfmt` for this project, without replacing your global settings.
- **Terminal:** `nix fmt home/editors.nix` formats a specific file. Review
  `git diff` before committing.

`.editorconfig` keeps indentation and line endings consistent. Add settings
to the file that owns the feature; avoid repeating options across modules.
Keep comments short and explain constraints rather than restating the code.

## What becomes live

| Files | When changes take effect |
|---|---|
| NixOS and home-manager modules | After `apply` |
| Compositor and terminal dotfiles | After push, input refresh, and rebuild; `apply` handles this |
| Neovim files in the dotfiles checkout | Live symlink; restart Neovim |
| Zed project settings and EditorConfig | When the editor reads the project |
| Noctalia seed files | First activation only; existing runtime files are preserved |
| Hyprland plugins | After rebuild and logout/login |

Edit source files in the repos, not generated links under `~/.config`.
Noctalia's writable runtime settings are an exception: changing a seed in
this repo does not overwrite an existing runtime file.

## Validate without deploying

From `~/nixos-config`, stage new files so the flake can see them, then run:

```sh
git diff --check
nix build .#nixosConfigurations.desktop.config.system.build.toplevel --no-link
nix build .#nixosConfigurations.vm.config.system.build.toplevel --no-link
nix flake check --no-write-lock-file
```

For unpushed compositor edits, add
`--override-input dotfiles path:/home/gav/Projects/dotfiles --no-write-lock-file`
to the build commands. This tests the local checkout without refreshing the
committed input. `apply` uses the pushed, lock-pinned input.

Keep one pending `cleanup/*` branch per repo. Commit there, return to clean
`main`, then run `apply` when ready. Do not reorder module imports casually:
list-valued options merge in import order.
