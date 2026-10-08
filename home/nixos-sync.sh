# nixos-sync update|dotsync|save — backs the fish helpers in home/shell.nix.
# NIXOS_SYNC_HOST (the flake output name) is set by writeShellApplication.

flake_dir="$HOME/nixos-config"
host="${NIXOS_SYNC_HOST:?}"
log_dir="${XDG_CACHE_HOME:-$HOME/.cache}/nixos-sync"
log=""    # raw output of the current command, see start_log
backup="" # pre-update copy of flake.lock
trap 'rm -f "$backup"' EXIT

if [[ -t 1 && -z "${NO_COLOR:-}" && "${TERM:-dumb}" != dumb ]]; then
  bold=$'\e[1m' green=$'\e[32m' yellow=$'\e[33m' red=$'\e[31m' reset=$'\e[0m'
else
  bold='' green='' yellow='' red='' reset=''
fi

section() { printf '\n%s── %s%s\n' "$bold" "$1" "$reset"; }
ok() { printf '%s✓%s %s\n' "$green" "$reset" "$1"; }
warn() { printf '%s⚠%s %s\n' "$yellow" "$reset" "$1"; }

die() {
  printf '%s✗%s %s\n' "$red" "$reset" "$1" >&2
  [[ -z "$log" ]] || printf '  Full log: %s\n' "$log" >&2
  exit 1
}

restore_and_die() {
  cp "$backup" flake.lock
  die "$1 flake.lock restored, nothing committed."
}

start_log() {
  mkdir -p "$log_dir"
  log="$log_dir/last-$1.log"
  printf '# nixos-sync %s for %s, %s\n' "$1" "$host" "$(date -Is)" >"$log"
}

# Output goes only to the log; printed in full if the command fails.
quiet() {
  local out rc=0
  out=$(mktemp)
  "$@" >"$out" 2>&1 || rc=$?
  { printf '$ %s\n' "$*"; cat "$out"; } >>"$log"
  ((rc == 0)) || cat "$out" >&2
  rm -f "$out"
  return "$rc"
}

# Runs on the terminal (nh's progress tree needs a TTY) with a copy in the log.
live() {
  printf '$ %s\n' "$*" >>"$log"
  SHELL="$BASH" script -qefa -c "$(printf '%q ' "$@")" "$log"
}

nh_switch() { live nh os switch "$flake_dir" -H "$host"; }

# One line per changed root input: name, old → new short rev, date of the new one.
print_changes() {
  local changes
  changes=$(jq -rn --slurpfile a "$1" --slurpfile b "$2" '
    def lock($l; $n): ($l.nodes[$l.nodes.root.inputs[$n]] // {}).locked // {};
    def short: (.rev // (.narHash // "-" | ltrimstr("sha256-")))[0:7];
    ($b[0].nodes.root.inputs | keys[]) as $n
    | lock($a[0]; $n) as $o | lock($b[0]; $n) as $w
    | select($o != $w)
    | [$n, ($o | short), ($w | short), ($w.lastModified // 0 | strftime("%Y-%m-%d"))]
    | @tsv')
  if [[ -z "$changes" ]]; then
    ok "All inputs already up to date"
    return
  fi
  local name old new date
  while IFS=$'\t' read -r name old new date; do
    printf '  %-26s %s → %s  (%s)\n' "$name" "$old" "$new" "$date"
  done <<<"$changes"
}

# Be on an up-to-date main. Only switch branches with a clean tree.
preflight() {
  cd "$flake_dir"
  local branch before
  branch=$(git branch --show-current)
  if [[ "$branch" != main ]]; then
    [[ -z "$(git status --porcelain)" ]] ||
      die "On branch '$branch' with uncommitted changes. Commit or stash them, then switch to main yourself."
    git switch -q main || die "Couldn't switch from '$branch' to main."
    ok "Switched from '$branch' to main"
  fi
  before=$(git rev-parse HEAD)
  quiet git pull --ff-only || die "git pull --ff-only failed (main and origin have diverged?). Fix it by hand."
  if [[ "$(git rev-parse HEAD)" == "$before" ]]; then
    ok "main is up to date with origin"
  else
    ok "Pulled $(git rev-list --count "$before..HEAD") new commit(s) from origin"
  fi
}

require_clean() {
  [[ -z "$(git status --porcelain)" ]] ||
    die "$flake_dir has uncommitted changes. Commit them (or run save) first."
}

# Commit flake.lock and nothing else; no-op when it didn't change.
commit_lock() {
  if git diff --quiet -- flake.lock; then
    ok "flake.lock unchanged, nothing to commit"
    return 1
  fi
  git commit -q -m "$1" -- flake.lock
  ok "Committed: $1"
}

after_switch() {
  if [[ "$(readlink -f /run/booted-system/kernel)" != "$(readlink -f /run/current-system/kernel)" ]] ||
    [[ "$(readlink -f /run/booted-system/kernel-modules)" != "$(readlink -f /run/current-system/kernel-modules)" ]]; then
    warn "Reboot needed (kernel or modules changed)"
  else
    ok "No reboot needed"
  fi
  local sys usr
  sys=$(systemctl --failed --no-legend --plain || true)
  usr=$(systemctl --user --failed --no-legend --plain || true)
  if [[ -z "$sys$usr" ]]; then
    ok "No failed units"
  else
    warn "Failed units:"
    [[ -z "$sys" ]] || printf '  system: %s\n' "${sys//$'\n'/$'\n'  system: }"
    [[ -z "$usr" ]] || printf '  user: %s\n' "${usr//$'\n'/$'\n'  user: }"
  fi
}

cmd_update() {
  start_log update
  section "Checking ~/nixos-config"
  preflight
  require_clean
  backup=$(mktemp)
  cp flake.lock "$backup"

  section "Updating inputs"
  quiet nix flake update --flake "$flake_dir" || restore_and_die "nix flake update failed."
  print_changes "$backup" flake.lock

  section "Switching ($host)"
  local msg="flake: update inputs"
  if ! nh_switch; then
    # Millennium's bun hash often goes stale upstream; retry with it held back.
    local q='.nodes.millennium.locked.rev'
    [[ "$(jq -r "$q" flake.lock)" != "$(jq -r "$q" "$backup")" ]] ||
      restore_and_die "Switch failed."
    warn "Switch failed. Retrying with Millennium held at its previous rev."
    cp "$backup" flake.lock
    local -a others
    mapfile -t others < <(jq -r '.nodes.root.inputs | keys[] | select(. != "millennium")' flake.lock)
    quiet nix flake update "${others[@]}" --flake "$flake_dir" || restore_and_die "nix flake update failed."
    print_changes "$backup" flake.lock
    nh_switch || restore_and_die "Switch failed with Millennium held back too."
    msg="flake: update inputs (Millennium held back)"
  fi
  ok "Switched to the new system"

  section "Wrapping up"
  if commit_lock "$msg"; then
    if quiet git push; then
      ok "Pushed to origin/main"
    else
      warn "Push failed (commit is local; run git push)"
    fi
  fi
  after_switch
}

cmd_dotsync() {
  start_log dotsync
  section "Checking ~/nixos-config"
  preflight
  require_clean
  backup=$(mktemp)
  cp flake.lock "$backup"

  section "Updating dotfiles"
  quiet nix flake update dotfiles --flake "$flake_dir" || restore_and_die "Dotfiles update failed."
  print_changes "$backup" flake.lock

  section "Switching ($host)"
  nh_switch || restore_and_die "Switch failed."
  ok "Switched to the new system"

  section "Wrapping up"
  commit_lock "flake: update dotfiles" || true
  after_switch
}

# Build-check, then commit tracked changes as-is. No input bumps, no switch.
cmd_save() {
  start_log save
  preflight
  nixos-rebuild build --flake "$flake_dir#$host" || die "Build failed. Nothing committed."
  if git diff --quiet && git diff --cached --quiet; then
    ok "Nothing to commit"
    return
  fi
  git add -u
  git commit -q -m "save: $(git diff --cached --name-only | paste -sd, - | sed 's/,/, /g')"
  ok "Committed tracked changes (not pushed)"
}

case "${1:-}" in
  update) cmd_update ;;
  dotsync) cmd_dotsync ;;
  save) cmd_save ;;
  *) die "usage: nixos-sync update|dotsync|save" ;;
esac
