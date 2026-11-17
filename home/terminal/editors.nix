# Neovim. Its config is a live link to ~/Projects/dotfiles/nvim, so edits
# there show up right away and the plugin manager can write its lock file.
{ config, pkgs, ... }:

{
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/dotfiles/nvim";
  home.sessionVariables.EDITOR = "nvim";

  # nvim runs in the terminal, so no launcher entry.
  xdg.dataFile."applications/nvim.desktop" = {
    force = true;
    text = "[Desktop Entry]\nHidden=true\n";
  };

  home.packages = [
    (pkgs.writeShellScriptBin "vim" ''exec nvim "$@"'')
    # Neovim builds its syntax parsers with these.
    pkgs.gcc
    pkgs.tree-sitter
    pkgs.nixfmt
  ];
}
