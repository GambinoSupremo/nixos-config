# Battle.net often stalls before it tries to sign in (cause unknown); a restart clears it far
# sooner than waiting. Exits 0 once signed in or WoW is running, 1 if it gave up.
logs="$HOME/Games/battlenet/drive_c/users/steamuser/AppData/Local/Battle.net/Logs"
prefix="$HOME/Games/battlenet/pfx/"
# Anchored on the Windows path: launcher shells keep Battle.net.exe in their args after it exits.
client='^C:.*Battle[.]net[.]exe'
wrapper='[l]utris-wrapper.*Games/battlenet'
tries=${BATTLENET_TRIES:-6}
stale_after=20 # seconds without a log line
wait_limit=180 # seconds per try when it isn't stalled, e.g. a real password prompt

client_pid() { pgrep -of "$client"; }
wow_running() { pgrep -x Wow.exe >/dev/null; }

# This client's logs; launcher shells add short ones, so the longest is the client's own.
client_logs() {
  local pid since
  pid=$(client_pid) || return 1
  since=$(($(date +%s) - $(ps -o etimes= -p "$pid")))
  find "$logs" -name 'battle.net-*.log' -newermt "@$since"
}

signed_in() {
  client_logs | xargs -r grep -l 'Logged into Battle.net successfully' | grep -q .
}

# Stalled: the log stopped short of sign-in while the main thread stays busy. A window waiting
# for a password should have an idle thread, so it's left alone.
stalled() {
  local pid log before after
  pid=$(client_pid) || return 1
  log=$(client_logs | xargs -r wc -l | grep -v ' total$' | sort -n | tail -1 | awk '{print $2}')
  [ -n "$log" ] || return 1
  [ $(($(date +%s) - $(stat -c %Y "$log"))) -ge "$stale_after" ] || return 1
  grep -q 'Reporting process' "$log" || return 1
  before=$(awk '{print $14 + $15}' "/proc/$pid/task/$pid/stat")
  sleep 3
  after=$(awk '{print $14 + $15}' "/proc/$pid/task/$pid/stat")
  cpu=$(((after - before) / 3))
  [ "$cpu" -ge 50 ]
}

stop_battlenet() {
  local p
  # Re-checked here: this also ends anything else in the prefix.
  wow_running && return 1
  for p in $(pgrep -x wineserver); do
    tr '\0' '\n' <"/proc/$p/environ" 2>/dev/null | grep -qx "WINEPREFIX=$prefix" && kill -TERM "$p"
  done
  sleep 3
  # Windows processes can outlive wineserver.
  for p in $(pgrep -f '^[Cc]:'); do
    tr '\0' '\n' <"/proc/$p/environ" 2>/dev/null | grep -qx "WINEPREFIX=$prefix" && kill -KILL "$p"
  done
  # A dead main thread hides Agent's cmdline from the filter above.
  pkill -KILL -x Agent.exe
  sleep 1
  pkill -TERM -f "$wrapper"
  for _ in $(seq 40); do
    if ! client_pid >/dev/null && ! pgrep -f "$wrapper" >/dev/null; then
      sleep 3
      return 0
    fi
    sleep 1
  done
  return 1
}

for try in $(seq "$tries"); do
  wow_running && exit 0
  seen=
  client_pid >/dev/null || systemctl --user start --no-block battlenet-background.service
  for _ in $(seq "$wait_limit"); do
    wow_running && exit 0
    if client_pid >/dev/null; then
      seen=1
      signed_in && { echo "signed in on try $try"; exit 0; }
      if stalled; then
        echo "try $try stalled (main thread ${cpu}% busy)"
        [ "$try" -lt "$tries" ] && { stop_battlenet || { echo "could not close Battle.net"; exit 1; }; }
        continue 2
      fi
    elif [ -n "$seen" ]; then
      echo "client exited"
      continue 2
    fi
    sleep 1
  done
  echo "no sign-in after ${wait_limit}s and not stalled; leaving it open"
  exit 1
done
echo "gave up after $tries tries; leaving the last one open"
exit 1
