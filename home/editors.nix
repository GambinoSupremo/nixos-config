# Neovim configuration and shared editing tools.
{ config, pkgs, ... }:

{
  # ── Neovim ───────────────────────────────────────────────────────────────────
  # LazyVim config linked live from the dotfiles checkout (not the pinned input)
  # so lazy.nvim can write lazy-lock.json. neovim itself is in systemPackages.
  # nvim runs in Ghostty; the package's "Neovim wrapper" launcher entry isn't needed.
  xdg.dataFile."applications/nvim.desktop" = {
    force = true;
    text = "[Desktop Entry]\nHidden=true\n";
  };
  xdg.configFile."nvim".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/Projects/dotfiles/nvim";
  home.sessionVariables.EDITOR = "nvim";
  home.packages = [
    (pkgs.writeShellScriptBin "vim" ''exec nvim "$@"'')
    # nvim-treesitter (main branch) compiles parsers with these.
    pkgs.gcc
    pkgs.tree-sitter
    pkgs.nixfmt
  ];
}
