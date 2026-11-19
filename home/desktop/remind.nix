# `remind`: one line, e.g. "call the bank tomorrow 5pm", becomes a Todoist task
# in Reminders with a due-time alert on the phone. Token in ~/.config/todoist/token.
{ pkgs, ... }:

let
  remind = pkgs.writeShellApplication {
    name = "remind";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.zenity
      pkgs.libnotify
    ];
    text = ''
      token_file=''${XDG_CONFIG_HOME:-$HOME/.config}/todoist/token
      [ -r "$token_file" ] || { notify-send -a Reminders "No Todoist token" "Put it in $token_file"; exit 1; }
      text=''${*:-$(zenity --entry --title=Reminder --text="What and when? (e.g. call the bank tomorrow 5pm)" --width=420)} || exit 0
      [ -n "''${text// /}" ] || exit 0
      body=$(jq -n --arg t "$text #Reminders" '{text: $t, auto_reminder: true}')
      if task=$(curl -sSf -X POST https://api.todoist.com/api/v1/tasks/quick \
        -H "Authorization: Bearer $(tr -d '[:space:]' <"$token_file")" \
        -H 'Content-Type: application/json' -d "$body"); then
        when=$(jq -r '.due.string // "no time set"' <<<"$task")
        notify-send -a Reminders "$(jq -r .content <<<"$task")" "$when"
      else
        notify-send -a Reminders "Couldn't add it" "$text"
      fi
    '';
  };
in
{
  home.packages = [ remind ];
}
