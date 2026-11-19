# `remind` / `r`: one line, e.g. "call the bank tomorrow 5pm", becomes a Todoist
# task in the Inbox. A once-a-minute check pops up any task with a set time, from
# any project, when it's due, with Done/Snooze.
# Token in ~/.config/todoist/token.
{ pkgs, lib, ... }:

let
  api = "https://api.todoist.com/api/v1";

  # Shared by all three scripts. seen: "<task>@<due> never|<snooze-until>".
  common = ''
    token_file=''${XDG_CONFIG_HOME:-$HOME/.config}/todoist/token
    state_dir=''${XDG_STATE_HOME:-$HOME/.local/state}/reminders
    seen=$state_dir/seen
    token() { tr -d '[:space:]' <"$token_file"; }
    set_seen() {
      mkdir -p "$state_dir"
      (
        flock 9
        touch "$seen"
        awk -v k="$1" '$1 != k' "$seen" >"$seen.tmp"
        echo "$1 $2" >>"$seen.tmp"
        mv "$seen.tmp" "$seen"
      ) 9>"$seen.lock"
    }
  '';

  deps = [
    pkgs.curl
    pkgs.jq
    pkgs.libnotify
    pkgs.util-linux # flock
    pkgs.gawk
  ];

  remind = pkgs.writeShellApplication {
    name = "remind";
    runtimeInputs = deps ++ [ pkgs.zenity ];
    text = common + ''
      [ -r "$token_file" ] || { notify-send -a Reminders "No Todoist token" "Put it in $token_file"; exit 1; }
      text=''${*:-$(zenity --entry --title=Reminder --text="What and when? (e.g. call the bank tomorrow 5pm)" --width=420)} || exit 0
      [ -n "''${text// /}" ] || exit 0
      body=$(jq -n --arg t "$text" '{text: $t, auto_reminder: true}')
      if task=$(curl -sSf -X POST ${api}/tasks/quick \
        -H "Authorization: Bearer $(token)" \
        -H 'Content-Type: application/json' -d "$body"); then
        when=$(jq -r '.due.string // "no time set"' <<<"$task")
        notify-send -a Reminders "$(jq -r .content <<<"$task")" "$when"
      else
        notify-send -a Reminders "Couldn't add it" "$text"
      fi
    '';
  };

  r = pkgs.writeShellScriptBin "r" ''exec ${lib.getExe remind} "$@"'';

  # One pop-up; waits for a click.
  popup = pkgs.writeShellApplication {
    name = "reminder-popup";
    runtimeInputs = deps;
    text = common + ''
      id=$1 key=$2 title=$3 body=$4
      action=$(notify-send -a Reminders -u critical -i appointment-soon \
        --action=done=Done --action=snooze="Snooze 10 min" --wait "$title" "$body" || true)
      case $action in
        done)
          if curl -sSf -X POST "${api}/tasks/$id/close" -H "Authorization: Bearer $(token)" >/dev/null; then
            notify-send -a Reminders -t 3000 "Done" "$title"
          else
            notify-send -a Reminders "Couldn't tick it off" "$title"
          fi
          ;;
        snooze) set_seen "$key" "$(($(date +%s) + 600))" ;;
      esac
    '';
  };

  # Finds timed tasks that are due and not shown yet; pops each up in its own unit.
  # Times are checked here: the API's today/overdue filters return nothing.
  check = pkgs.writeShellApplication {
    name = "reminders-check";
    runtimeInputs = deps ++ [ pkgs.systemd ];
    text = common + ''
      mkdir -p "$state_dir"
      touch "$seen"
      fails=$state_dir/fails
      if ! [ -r "$token_file" ] || ! tasks=$(curl -sSf -G --max-time 20 ${api}/tasks/filter \
        -H "Authorization: Bearer $(token)" \
        --data-urlencode 'query=!no time' --data-urlencode limit=200); then
        n=$(($(cat "$fails" 2>/dev/null || echo 0) + 1))
        echo "$n" >"$fails"
        if [ "$n" -eq 5 ]; then
          notify-send -a Reminders "Reminders can't reach Todoist" \
            "PC pop-ups are paused until it's back. Phone alerts still work."
        fi
        exit 0
      fi
      rm -f "$fails"

      now=$(date +%s)
      keys=()
      while IFS=$'\t' read -r id due content; do
        at=$(date -d "$due" +%s)
        key="$id@$due"
        keys+=("$key")
        ((at <= now)) || continue
        next=$(awk -v k="$key" '$1 == k { print $2 }' "$seen")
        if [ "$next" = never ] || { [ -n "$next" ] && ((next > now)); }; then continue; fi
        if [ "$(date -d "@$at" +%F)" = "$(date +%F)" ]; then when="Due $(date -d "@$at" '+%-I:%M %p')"
        else when="Due $(date -d "@$at" '+%a %-I:%M %p')"; fi
        set_seen "$key" never
        systemd-run --user --collect --quiet ${lib.getExe popup} "$id" "$key" "$content" "$when"
      done < <(jq -r '.results[] | select(.due.date // "" | contains("T")) | [.id, .due.date, .content] | @tsv' <<<"$tasks")

      # Forget reminders that are done or moved.
      (
        flock 9
        printf '%s\n' "''${keys[@]}" >"$state_dir/current"
        awk 'NR == FNR { k[$1]; next } $1 in k' "$state_dir/current" "$seen" >"$seen.tmp"
        mv "$seen.tmp" "$seen"
      ) 9>"$seen.lock"
    '';
  };
in
{
  home.packages = [
    remind
    r
  ];

  systemd.user.services.reminders-check = {
    Unit.Description = "Pop up due Todoist reminders";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe check;
    };
  };
  systemd.user.timers.reminders-check = {
    Unit = {
      Description = "Check Todoist reminders every minute";
      PartOf = [ "graphical-session.target" ];
    };
    Timer = {
      OnCalendar = "*:*:00";
      AccuracySec = "1s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
