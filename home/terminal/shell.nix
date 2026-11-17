# Fish shell: greeting, aliases, the apply/update commands, and small helpers.
{ pkgs, host, ... }:

let
  # The script behind apply, update, dotsync and save.
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
  home.packages = [ pkgs.krabby ]; # the Pokémon in the greeting

  # --- Fish ---
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
    functions = {
      apply = "${nixosSync}/bin/nixos-sync apply";
      update = "${nixosSync}/bin/nixos-sync update";
      dotsync = "${nixosSync}/bin/nixos-sync dotsync";
      save = "${nixosSync}/bin/nixos-sync save";
    };
  };

  # --- Helpers ---
  programs.fzf = {
    enable = true;
    enableFishIntegration = false; # it would take over Ctrl+T
  };

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.bat = {
    enable = true;
    config = {
      theme = "base16";
      style = "plain";
    };
  };

  # Lets one-off nix-shell / nix-env use unfree packages too.
  xdg.configFile."nixpkgs/config.nix" = {
    force = true;
    text = "{ allowUnfree = true; }\n";
  };
}
