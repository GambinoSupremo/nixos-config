# Shell stack: fish (aliases, greeting), starship, fzf, zoxide, bat.
# The standalone fish config in the dotfiles repo is NOT deployed on NixOS;
# this file is the single owner of interactive-shell behavior here.
{ pkgs, ... }:

{
  # pokemon-colorscripts: shown on every new shell — CachyOS parity.
  home.packages = [
    pkgs.pokemon-colorscripts
    # Flags when the electron-40.10.5 exception in nixos/base/core.nix is removable.
    (pkgs.writeShellScriptBin "insecure-pin-check" ''
      rev=$(${pkgs.jq}/bin/jq -r '.nodes.nixpkgs.locked.rev' ~/nixos-config/flake.lock)
      if nix eval "github:nixos/nixpkgs/$rev#tidal-hifi.drvPath" >/dev/null 2>&1 \
         && NIXPKGS_ALLOW_UNFREE=1 nix eval --impure "github:nixos/nixpkgs/$rev#obsidian.drvPath" >/dev/null 2>&1; then
        echo "electron-40.10.5 exception no longer needed: remove permittedInsecurePackages from nixos/base/core.nix and this check"
      fi
    '')
  ];

  # ── Fish ─────────────────────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting ""
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
      # Refresh only the dotfiles pin, then rebuild.
      dotsync = "nix flake update dotfiles --flake ~/nixos-config && sudo nixos-rebuild switch --flake ~/nixos-config#desktop";
      # CURRENTLY INERT: updater.sh isn't installed, and arkenfox fights
      # zen.nix's declarative user.js — decide which owns it before first use.
      arkenfox-update = "bash ~/.config/zen/default/updater.sh";
    };
    # `update` is a function, not an alias, so a bad upstream bump can revert
    # flake.lock instead of leaving the repo stuck on a revision that won't build.
    functions = {
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
            insecure-pin-check
            rm $backup
        else
            echo "rebuild failed — reverting flake.lock to the pre-update state"
            cp $backup $lock
            rm $backup
            return 1
        end
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
