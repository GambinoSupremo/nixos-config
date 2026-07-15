{ pkgs, ... }:

{
  # pokemon-colorscripts: shown on every new shell — CachyOS parity.
  home.packages = [ pkgs.pokemon-colorscripts ];

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
      # update = lock refresh AND rebuild in one step. A bare `nix flake
      # update` only rewrites flake.lock — nothing lands until the rebuild
      # (which is how a 2026-07-13 update sat unapplied on a 07-09 system).
      update  = "nix flake update --flake ~/nixos-config && sudo nixos-rebuild switch --flake ~/nixos-config#desktop";
    };
  };

  # ── Starship ─────────────────────────────────────────────────────────────────
  programs.starship = {
    enable                = true;
    enableFishIntegration = true;
    # starship init fish | source goes into shellInitLast so nothing sourced
    # later can shadow fish_prompt. enableInteractive = false achieves this.
    enableInteractive     = false;
    # settings left unset — ~/.config/starship.toml is written by
    # home.activation.starshipConfig in dotfiles.nix (merges the dotfiles
    # layout with Noctalia's runtime palette block; must stay a writable file).
  };

  # ── fzf ──────────────────────────────────────────────────────────────────────
  programs.fzf = {
    enable = true;
    # Fish integration disabled — it binds Ctrl+T which conflicts with
    # Fish's built-in transpose-chars.
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
