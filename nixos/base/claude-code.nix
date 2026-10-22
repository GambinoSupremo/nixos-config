# Claude Code and its system policy. Managed settings outrank
# ~/.claude/settings.json, which Claude Code still writes to.
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.claude-code ];

  # No attribution trailers, PR footer or session link.
  environment.etc."claude-code/managed-settings.json".text = builtins.toJSON {
    attribution = {
      commit = "";
      pr = "";
      sessionUrl = false;
    };
  };
}
