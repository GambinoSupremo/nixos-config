# nixos-sync apply|update|dotsync|save — backs the fish helpers in home/shell.nix.
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

# Runs on the terminal (sudo needs a TTY) with a copy in the log.
live() {
  printf '$ %s\n' "$*" >>"$log"
  SHELL="$BASH" script -qefa -c "$(printf '%q ' "$@")" "$log"
}

# Build behind a one-line spinner; the build output only goes to the log.
build_system() {
  local target_host="${1:-$host}" dotfiles_dir="${2:-}"
  local attr="$flake_dir#nixosConfigurations.$target_host.config.system.build.toplevel"
  local blog out pid rc=0 start=$SECONDS i=0 total started cur status
  local -a frames=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
  local -a cmd=(nix build --no-link --print-out-paths --log-format raw)
  if [[ -n "$dotfiles_dir" ]]; then
    # git+file, not path: builds the committed tree, so it matches the pin after pushing.
    cmd+=(--override-input dotfiles "git+file://$dotfiles_dir")
  fi
  cmd+=("$attr")
  blog=$(mktemp) out=$(mktemp)
  "${cmd[@]}" >"$out" 2>"$blog" &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    if [[ -t 1 ]]; then
      total=$(sed -nE 's/^these ([0-9]+) derivations will be built:$/\1/p; s/^this derivation will be built:$/1/p' "$blog" | tail -1)
      started=$(sed -n "/^building '/p" "$blog" | wc -l)
      cur=$(sed -nE "s|^building '/nix/store/[a-z0-9]{32}-(.*)\.drv'.*|\1|p" "$blog" | tail -1)
      if [[ -n "$cur" ]]; then
        status="Building $started/${total:-?}  ${cur:0:40}"
      elif [[ -n "$(sed -n "/^copying path /{p;q}" "$blog")" ]]; then
        status="Downloading"
      else
        status="Evaluating"
      fi
      printf '\r\e[K%s %s  %s%ss%s' "${frames[i++ % 10]}" "$status" "$bold" "$((SECONDS - start))" "$reset"
    fi
    sleep 0.15
  done
  wait "$pid" || rc=$?
  [[ ! -t 1 ]] || printf '\r\e[K'
  { printf '$'; printf ' %q' "${cmd[@]}"; printf '\n'; cat "$blog"; } >>"$log"
  if ((rc == 0)); then
    new_system=$(tail -n 1 "$out")
    total=$(sed -nE 's/^these ([0-9]+) derivations will be built:$/\1/p; s/^this derivation will be built:$/1/p' "$blog" | tail -1)
    ok "Built in $((SECONDS - start))s (${total:-0} to build, rest downloaded or cached)"
  else
    tail -n 30 "$blog" >&2
  fi
  rm -f "$blog" "$out"
  return "$rc"
}

# dix's package diff without the store paths, path counts and total size.
show_diff() {
  local d
  d=$(dix --color always /run/current-system "$new_system" 2>/dev/null |
    sed -E '/(<<<|>>>|PATHS|SIZE)/d' | awk 'NF { if (n++ && gap) print ""; gap = 0; print; next } { gap = 1 }')
  if [[ "$d" == *'['* ]]; then
    printf '%s\n' "$d" | sed 's/^/  /'
  else
    ok "No package changes"
  fi
}

new_system=""
nh_switch() {
  local dotfiles_dir="${1:-}"
  local desktop_system vm_system
  section "Building desktop"
  build_system desktop "$dotfiles_dir" || return
  desktop_system="$new_system"
  section "Building VM validation target"
  build_system vm "$dotfiles_dir" || return
  vm_system="$new_system"
  if [[ "$host" == desktop ]]; then
    new_system="$desktop_system"
  else
    new_system="$vm_system"
  fi
  section "Changes"
  show_diff
  section "Activating"
  live nh os switch "$new_system" --no-nom --diff never -q && return
  # A unit failing during activation still leaves the new system live.
  [[ "$(readlink -f /run/current-system)" != "$new_system" ]] || return 2
  return 1
}

# nh_switch returned 2: keep things local so the repo matches what is running.
live_with_errors() {
  warn "The new system is live, but activation reported errors (see above). $1"
  after_switch
  exit 1
}

# One line per changed root input: name, old → new short rev, date of the new one.
print_changes() {
  local changes
  changes=$(jq -rn --slurpfile a "$1" --slurpfile b "$2" '
    # Inputs new in this run (or a follows path) have no node in the old lock.
    def lock($l; $n): $l.nodes.root.inputs[$n] as $k
      | if ($k | type) == "string" then ($l.nodes[$k] // {}).locked // {} else {} end;
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

# Be on an up-to-date main (in $1, default nixos-config). Only switch branches
# with a clean tree.
preflight() {
  cd "${1:-$flake_dir}"
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
    die "$PWD has uncommitted changes. Commit them (or run save) first."
}

# Commit flake.lock and nothing else; no-op when it didn't change.
commit_lock() {
  if git diff --quiet -- flake.lock; then
    ok "flake.lock unchanged, nothing to commit"
    return 1
  fi
  git commit -q -m "$1" -- flake.lock || die "Couldn't commit flake.lock."
  ok "Committed: $1"
}

push_lock() {
  if quiet git push; then
    ok "Pushed to origin/main"
  else
    warn "Push failed (commit is local; run git push)"
    return 1
  fi
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

  section "Building ($host)"
  local rc=0
  nh_switch || rc=$?
  if ((rc == 2)); then
    commit_lock "flake: update inputs" || true
    live_with_errors "Not pushed."
  fi
  ((rc == 0)) || restore_and_die "Switch failed."
  ok "Switched to the new system"

  section "Wrapping up"
  if commit_lock "flake: update inputs"; then
    if ! push_lock; then
      after_switch
      return 1
    fi
  fi
  after_switch
}

# The one cleanup/* branch in $PWD with commits main lacks, or empty. Checked in
# both repos before merging either, so a refusal leaves both mains untouched.
pending=""
find_pending() {
  local b
  local -a branches found=()
  mapfile -t branches < <(git for-each-ref --format='%(refname:short)' refs/heads/cleanup/)
  for b in "${branches[@]}"; do
    [[ "$(git cherry main "$b")" != *+* ]] || found+=("$b")
  done
  ((${#found[@]} <= 1)) ||
    die "More than one branch waiting in $PWD (${found[*]}). Consolidate them into one cleanup branch."
  pending=${found[0]:-}
  [[ -z "$pending" ]] || git merge-base --is-ancestor main "$pending" ||
    die "Cannot fast-forward '$pending' in $PWD. Rebase it onto main, then retry."
}

land_branch() {
  if [[ -z "$1" ]]; then
    ok "No pending cleanup branch"
    return
  fi
  quiet git merge --ff-only "$1" || die "Couldn't fast-forward main to '$1'."
  ok "Merged $1"
}

# Delete cleanup/* branches, local and on origin, that are fully on main.
prune_branches() {
  local b
  local -a branches
  mapfile -t branches < <(git for-each-ref --format='%(refname:short)' refs/heads/cleanup/)
  for b in "${branches[@]}"; do
    [[ "$(git cherry main "$b")" == *+* ]] || { git branch -q -D "$b" && ok "Deleted branch $b"; }
  done
  mapfile -t branches < <(git for-each-ref --format='%(refname:lstrip=3)' refs/remotes/origin/cleanup/)
  for b in "${branches[@]}"; do
    [[ "$(git cherry main "origin/$b")" == *+* ]] && continue
    if quiet git push origin --delete "$b"; then
      ok "Deleted branch $b on GitHub"
    else
      warn "Couldn't delete $b on GitHub"
    fi
  done
}

# Validate both hosts before publishing or pruning cleanup branches.
cmd_apply() {
  start_log apply
  local before dot_before="" dot_dir="$HOME/Projects/dotfiles" dotfiles_override="" nix_branch dot_branch="" rc=0
  section "Checking ~/nixos-config"
  preflight
  require_clean
  before=$(git rev-parse HEAD)
  backup=$(mktemp)
  cp flake.lock "$backup"

  if [[ -d "$dot_dir/.git" ]]; then
    dotfiles_override="$dot_dir"
    section "Checking ~/Projects/dotfiles"
    preflight "$dot_dir"
    require_clean
    dot_before=$(git -C "$dot_dir" rev-parse HEAD)
  fi

  cd "$flake_dir"
  find_pending
  nix_branch=$pending
  if [[ -n "$dotfiles_override" ]]; then
    cd "$dot_dir"
    find_pending
    dot_branch=$pending
    land_branch "$dot_branch"
    cd "$flake_dir"
  fi
  land_branch "$nix_branch"

  section "Validating and activating ($host)"
  nh_switch "$dotfiles_override" || rc=$?
  ((rc != 2)) || live_with_errors "Nothing pushed; run apply again once fixed to publish."
  if ((rc != 0)); then
    git reset -q --hard "$before"
    [[ -z "$dotfiles_override" ]] || git -C "$dot_dir" reset -q --hard "$dot_before"
    die "Validation or activation failed. Local main branches were restored; cleanup branches remain."
  fi
  ok "Both hosts validated and $host activated"

  if [[ -n "$dotfiles_override" && -n "$(git -C "$dot_dir" rev-list origin/main..main)" ]]; then
    if ! quiet git -C "$dot_dir" push; then
      warn "System activated; dotfiles push failed. Local commits and cleanup branches were kept."
      after_switch
      return 1
    fi
    ok "Pushed dotfiles after validation"
  fi

  section "Refreshing the dotfiles pin"
  if ! quiet nix flake update dotfiles --refresh --flake "$flake_dir"; then
    warn "System activated, but the dotfiles pin refresh failed. Run dotsync to finish."
    after_switch
    return 1
  fi
  print_changes "$backup" flake.lock

  section "Publishing nixos-config"
  commit_lock "flake: update dotfiles" || true
  if quiet git push; then
    ok "Pushed nixos-config"
    if [[ -n "$dotfiles_override" ]]; then
      cd "$dot_dir"
      prune_branches
      cd "$flake_dir"
    fi
    prune_branches
  else
    warn "System activated; nixos-config push failed. Local commits and cleanup branches were kept."
    after_switch
    return 1
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
  # --refresh: Nix caches the GitHub branch for an hour, so a fresh push can be missed.
  quiet nix flake update dotfiles --refresh --flake "$flake_dir" || restore_and_die "Dotfiles update failed."
  print_changes "$backup" flake.lock

  section "Building ($host)"
  local rc=0
  nh_switch || rc=$?
  if ((rc == 2)); then
    commit_lock "flake: update dotfiles" || true
    live_with_errors "Not pushed."
  fi
  ((rc == 0)) || restore_and_die "Switch failed."
  ok "Switched to the new system"

  section "Wrapping up"
  if commit_lock "flake: update dotfiles"; then
    if ! push_lock; then
      after_switch
      return 1
    fi
  fi
  after_switch
}

# Build-check, then commit tracked changes as-is. No input bumps, no switch.
cmd_save() {
  start_log save
  preflight
  live nixos-rebuild build --flake "$flake_dir#$host" || die "Build failed. Nothing committed."
  if git diff --quiet && git diff --cached --quiet; then
    ok "Nothing to commit"
    return
  fi
  git add -u
  git commit -q -m "save: $(git diff --cached --name-only | paste -sd, - | sed 's/,/, /g')"
  ok "Committed tracked changes (not pushed)"
}

case "${1:-}" in
  apply) cmd_apply ;;
  update) cmd_update ;;
  dotsync) cmd_dotsync ;;
  save) cmd_save ;;
  *) die "usage: nixos-sync apply|update|dotsync|save" ;;
esac
