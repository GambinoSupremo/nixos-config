# Claude Code per-user config; package + managed policy are in nixos/base/claude-code.nix.
# Don't set settings, marketplaces or disabled servers here: ~/.claude/settings.json is hand-managed.
{ config, pkgs, ... }:

{
  programs.claude-code = {
    enable = true;
    package = null; # installed system-wide
    configDir = "${config.home.homeDirectory}/.claude"; # pin; HM default moves at 26.11
    mcpServers.nixos = {
      type = "stdio";
      command = "${pkgs.mcp-nixos}/bin/mcp-nixos";
    };
  };
}
