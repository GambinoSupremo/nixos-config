# Shell stack: fish (aliases, greeting), starship, fzf, zoxide, bat.
# The standalone fish config in the dotfiles repo is NOT deployed on NixOS;
# this file is the single owner of interactive-shell behavior here.
{ pkgs, ... }:

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
      ls      = "eza --icons --group-directories-first";
      la      = "eza -la --icons --group-directories-first";
      ll      = "eza -l --icons --group-directories-first";
      tree    = "eza --tree --icons --group-directories-first";
      cat     = "bat --style=plain";
      grep    = "rg";
      rebuild = "sudo nixos-rebuild switch --flake ~/nixos-config#desktop";
    };
    # `update`/`dotsync` are functions, not aliases, so a bad upstream bump can
    # revert flake.lock instead of leaving the repo stuck on a revision that
    # won't build. On a successful rebuild they also commit whatever's dirty
    # in nixos-config (flake.lock plus any pending edits) and push — if it
    # builds, it's a reasonable commit point, and this way the tree never
    # sits dirty and origin never falls behind.
    functions = {
      _nixos-commit-dirty = ''
        set -l flake_dir $argv[1]
        set -l label $argv[2]
        if not git -C $flake_dir diff --quiet; or not git -C $flake_dir diff --cached --quiet
            git -C $flake_dir add -A
            git -C $flake_dir commit -m "$label: "(git -C $flake_dir diff --cached --name-only | string join ', ') >/dev/null
        end
        # Push whatever's ahead of origin, including commits from earlier runs
        # that never made it out.
        git -C $flake_dir push
      '';

      # Checkpoint whatever's dirty in nixos-config as-is, no input bumps.
      # Confirms it still builds first so a broken edit never gets pushed.
      save = ''
        set -l flake_dir ~/nixos-config
        if nixos-rebuild build --flake $flake_dir#desktop
            _nixos-commit-dirty $flake_dir save
        else
            echo "build failed — nothing committed"
            return 1
        end
      '';

      update = ''
        set -l flake_dir ~/nixos-config
        set -l lock $flake_dir/flake.lock
        set -l backup (mktemp)
        cp $lock $backup

        if not nix flake update --flake $flake_dir
            echo "flake update failed — flake.lock left untouched"
            rm $backup
            return 1
        end

        if sudo nixos-rebuild switch --flake $flake_dir#desktop
            rm $backup
            _nixos-commit-dirty $flake_dir update
            return
        end

        # Millennium's bun hash often goes stale upstream; retry with it held back.
        set -l mill_rev '.nodes.millennium.locked.rev'
        if test (jq -r $mill_rev $lock) != (jq -r $mill_rev $backup)
            echo "rebuild failed — retrying with Millennium held at its previous rev"
            cp $backup $lock
            set -l others (jq -r '.nodes.root.inputs | keys[] | select(. != "millennium")' $lock)
            if nix flake update $others --flake $flake_dir
                and sudo nixos-rebuild switch --flake $flake_dir#desktop
                rm $backup
                _nixos-commit-dirty $flake_dir update
                echo "note: Millennium held back (new upstream rev failed to build)"
                return
            end
        end

        echo "rebuild failed — reverting flake.lock to the pre-update state"
        cp $backup $lock
        rm $backup
        return 1
      '';

      # Refresh only the dotfiles pin, then rebuild.
      dotsync = ''
        set -l flake_dir ~/nixos-config
        set -l lock $flake_dir/flake.lock
        set -l backup (mktemp)
        cp $lock $backup

        if not nix flake update dotfiles --flake $flake_dir
            echo "dotfiles update failed — flake.lock left untouched"
            rm $backup
            return 1
        end

        if sudo nixos-rebuild switch --flake $flake_dir#desktop
            rm $backup
            _nixos-commit-dirty $flake_dir dotsync
        else
            echo "rebuild failed — reverting flake.lock to the pre-update state"
            cp $backup $lock
            rm $backup
            return 1
        end
      '';

      # Claude Code won't persist trust for $HOME; launch from nixos-config instead.
      claude = ''
        test "$PWD" = "$HOME"; and cd ~/nixos-config
        command claude $argv
      '';
    };
  };

  # ── Starship ─────────────────────────────────────────────────────────────────
  programs.starship = {
    enable                = true;
    enableFishIntegration = true;
    # false puts the init in shellInitLast so nothing can shadow fish_prompt.
    enableInteractive     = false;
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
    enable                = true;
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
