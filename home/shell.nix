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
