# Shell stack: fish (aliases, greeting), starship, fzf, zoxide, bat.
# There is no fish config in the dotfiles repo;
# this file is the single owner of interactive-shell behavior here.
{ pkgs, host, ... }:

let
  # Backs the apply/update/dotsync/save fish functions. writeShellApplication runs
  # shellcheck at build time.
  nixosSync = pkgs.writeShellApplication {
    name = "nixos-sync";
    runtimeInputs = [
      pkgs.git
      pkgs.jq
      pkgs.nh
      pkgs.coreutils
      pkgs.gnused
      pkgs.util-linux # script(1): keeps the sudo prompt on a TTY while logging
      pkgs.dix
    ];
    runtimeEnv.NIXOS_SYNC_HOST = host.name;
    text = builtins.readFile ./nixos-sync.sh;
  };
in
{
  # krabby: a Pokémon on every new shell (pokemon-colorscripts' sprites, plus Gen 9).
  home.packages = [
    pkgs.krabby
  ];

  # ── Fish ─────────────────────────────────────────────────────────────────────
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set fish_greeting ""
      fish_add_path -g ~/.local/bin  # user-installed CLIs
      # A krabby Pokémon on each new shell; 1 in 40 is shiny, with a sparkle at its top right.
      if command -q krabby
        set -l shiny
        test (random 1 40) -eq 1; and set shiny --shiny
        set -l art (krabby random --no-title $shiny 2>/dev/null)
        # Drop krabby's blank padding rows so the prompt sits close under the sprite.
        while set -q art[1]; and test -z (string replace -ra '\e\[[0-9;]*m' "" -- $art[-1] | string trim)
          set -e art[-1]
        end
        while set -q art[1]; and test -z (string replace -ra '\e\[[0-9;]*m' "" -- $art[1] | string trim)
          set -e art[1]
        end
        if set -q art[1]
          set -q shiny[1]; and set art[1] "$art[1]  ✨"
          printf '%s\n' $art
        end
      end
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
    # apply: land Claude's branches, switch, push. update: main + clean + pull,
    # update all inputs, switch, commit only flake.lock and push.
    functions = {
      apply = "${nixosSync}/bin/nixos-sync apply";
      update = "${nixosSync}/bin/nixos-sync update";
      dotsync = "${nixosSync}/bin/nixos-sync dotsync";
      save = "${nixosSync}/bin/nixos-sync save";

      # Claude Code won't persist trust for $HOME; ~/Projects is the hub instead.
      claude = ''
        test "$PWD" = "$HOME"; and cd ~/Projects
        command claude $argv
      '';
      # Jump to a project and pick from its chats.
      nx = "cd ~/nixos-config; and command claude -r $argv";
      lab = "cd ~/Projects/homelab; and command claude -r $argv";
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
