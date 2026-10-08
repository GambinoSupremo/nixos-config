# Shell stack: fish (aliases, greeting), starship, fzf, zoxide, bat.
# There is no fish config in the dotfiles repo;
# this file is the single owner of interactive-shell behavior here.
{ pkgs, host, ... }:

let
  # Backs the update/dotsync/save fish functions. writeShellApplication runs
  # shellcheck at build time.
  nixosSync = pkgs.writeShellApplication {
    name = "nixos-sync";
    runtimeInputs = [
      pkgs.git
      pkgs.jq
      pkgs.coreutils
      pkgs.gnused
    ];
    text = ''
      flake_dir="$HOME/nixos-config"
      host="${host.name}"
      backup="" # pre-update copy of flake.lock
      trap 'rm -f "$backup"' EXIT

      die() {
        echo "$*" >&2
        exit 1
      }

      restore_and_die() {
        cp "$backup" flake.lock
        die "$1 flake.lock restored, nothing committed."
      }

      # Be on an up-to-date main. Only switch branches with a clean tree.
      preflight() {
        cd "$flake_dir"
        local branch
        branch=$(git branch --show-current)
        if [[ "$branch" != main ]]; then
          [[ -z "$(git status --porcelain)" ]] ||
            die "On branch '$branch' with uncommitted changes. Commit or stash them, then switch to main yourself."
          git switch -q main || die "Couldn't switch from '$branch' to main."
          echo "Switched from '$branch' to main."
        fi
        git pull --ff-only -q || die "git pull --ff-only failed (main and origin have diverged?). Fix it by hand."
      }

      require_clean() {
        [[ -z "$(git status --porcelain)" ]] ||
          die "$flake_dir has uncommitted changes. Commit them (or run save) first."
      }

      switch() { sudo nixos-rebuild switch --flake "$flake_dir#$host"; }

      # Commit flake.lock and nothing else; no-op when it didn't change.
      commit_lock() {
        if git diff --quiet -- flake.lock; then
          echo "flake.lock unchanged, nothing to commit."
          return 1
        fi
        git commit -q -m "$1" -- flake.lock
        echo "Committed: $1"
      }

      after_switch() {
        if [[ "$(readlink -f /run/booted-system/kernel)" != "$(readlink -f /run/current-system/kernel)" ]] ||
          [[ "$(readlink -f /run/booted-system/kernel-modules)" != "$(readlink -f /run/current-system/kernel-modules)" ]]; then
          echo "Reboot needed (kernel or modules changed)"
        else
          echo "No reboot needed"
        fi
        local sys usr
        sys=$(systemctl --failed --no-legend --plain || true)
        usr=$(systemctl --user --failed --no-legend --plain || true)
        if [[ -z "$sys$usr" ]]; then
          echo "No failed units"
        else
          echo "Failed units:"
          [[ -z "$sys" ]] || printf '  system: %s\n' "''${sys//$'\n'/$'\n'  system: }"
          [[ -z "$usr" ]] || printf '  user: %s\n' "''${usr//$'\n'/$'\n'  user: }"
        fi
      }

      cmd_update() {
        preflight
        require_clean
        backup=$(mktemp)
        cp flake.lock "$backup"

        nix flake update --flake "$flake_dir" || restore_and_die "nix flake update failed."
        local msg="flake: update inputs"
        if ! switch; then
          # Millennium's bun hash often goes stale upstream; retry with it held back.
          local q='.nodes.millennium.locked.rev'
          [[ "$(jq -r "$q" flake.lock)" != "$(jq -r "$q" "$backup")" ]] ||
            restore_and_die "Rebuild failed."
          echo "Rebuild failed. Retrying with Millennium held at its previous rev."
          cp "$backup" flake.lock
          local -a others
          mapfile -t others < <(jq -r '.nodes.root.inputs | keys[] | select(. != "millennium")' flake.lock)
          nix flake update "''${others[@]}" --flake "$flake_dir" || restore_and_die "nix flake update failed."
          switch || restore_and_die "Rebuild failed with Millennium held back too."
          msg="flake: update inputs (Millennium held back)"
        fi

        if commit_lock "$msg"; then
          if git push -q; then
            echo "Pushed to origin/main"
          else
            echo "Push failed (commit is local; run git push)"
          fi
        fi
        after_switch
      }

      cmd_dotsync() {
        preflight
        require_clean
        backup=$(mktemp)
        cp flake.lock "$backup"
        nix flake update dotfiles --flake "$flake_dir" || restore_and_die "Dotfiles update failed."
        switch || restore_and_die "Rebuild failed."
        commit_lock "flake: update dotfiles" || true
        after_switch
      }

      # Build-check, then commit tracked changes as-is. No input bumps, no switch.
      cmd_save() {
        preflight
        nixos-rebuild build --flake "$flake_dir#$host" || die "Build failed. Nothing committed."
        if git diff --quiet && git diff --cached --quiet; then
          echo "Nothing to commit."
          return
        fi
        git add -u
        git commit -q -m "save: $(git diff --cached --name-only | paste -sd, - | sed 's/,/, /g')"
        echo "Committed tracked changes (not pushed)."
      }

      case "''${1:-}" in
        update) cmd_update ;;
        dotsync) cmd_dotsync ;;
        save) cmd_save ;;
        *) die "usage: nixos-sync update|dotsync|save" ;;
      esac
    '';
  };
in
{
  # pokemon-colorscripts: shown on every new shell — CachyOS parity.
  home.packages = [
    pkgs.pokemon-colorscripts
  ];

  # ── Fish ─────────────────────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting ""
      fish_add_path -g ~/.local/bin  # user-installed CLIs
      command -q pokemon-colorscripts; and pokemon-colorscripts --no-title -r 2>/dev/null || true
    '';
    shellAliases = {
      ls = "eza --icons --group-directories-first";
      la = "eza -la --icons --group-directories-first";
      ll = "eza -l --icons --group-directories-first";
      tree = "eza --tree --icons --group-directories-first";
      cat = "bat";
      grep = "rg";
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#${host.name}";
    };
    # update: main + clean + pull, update all inputs, switch, commit only
    # flake.lock and push. dotsync/save: same checks, commit but never push.
    functions = {
      update = "${nixosSync}/bin/nixos-sync update";
      dotsync = "${nixosSync}/bin/nixos-sync dotsync";
      save = "${nixosSync}/bin/nixos-sync save";

      # Claude Code won't persist trust for $HOME; launch from nixos-config instead.
      claude = ''
        test "$PWD" = "$HOME"; and cd ~/nixos-config
        command claude $argv
      '';
    };
  };

  # ── Starship ─────────────────────────────────────────────────────────────────
  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    # false puts the init in shellInitLast so nothing can shadow fish_prompt.
    enableInteractive = false;
    # settings unset — starship.toml is written by home.activation.starshipConfig
    # (dotfiles.nix) and must stay a writable file.
  };

  # ── fzf ──────────────────────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    # Off — it binds Ctrl+T over fish's transpose-chars.
    enableFishIntegration = false;
  };

  # ── zoxide ───────────────────────────────────────────────────────────────────
  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  # ── bat ──────────────────────────────────────────────────────────────────────
  programs.bat = {
    enable = true;
    config = {
      theme = "base16";
      style = "plain";
    };
  };
}
