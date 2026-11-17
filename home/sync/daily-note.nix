# Where the Obsidian daily notes live, used by game-log.
# Must match the vault's .obsidian/daily-notes.json.
{ lib, ... }:

{
  options.gav.dailyNote = {
    folder = lib.mkOption {
      type = lib.types.str;
      default = "Journal/Daily";
      description = "Daily notes folder, relative to the vault.";
    };
    format = lib.mkOption {
      type = lib.types.str;
      default = "YYYY/MM MMMM/[Week] W/YYYY-MM-DD";
      description = "Daily note path inside the folder (W = ISO week, unpadded).";
    };
  };
}
