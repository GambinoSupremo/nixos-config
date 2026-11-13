# Where the Obsidian daily notes live, read by game-log (Todoist, Garmin and
# Plex logging moved to the lifelog server).
# Same moment.js syntax as the vault's .obsidian/daily-notes.json; keep the two in step.
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
