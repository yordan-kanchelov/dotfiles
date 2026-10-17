#!/usr/bin/env bash
# Local Git integration tests; no WSL, network, package installs or Ansible needed.
# On Git Bash, set TMPDIR to a native C:/... scratch directory before running.
set -euo pipefail
: "${TMPDIR:?Set TMPDIR to a scratch directory before running these tests}"

native_path() {
  if command -v cygpath >/dev/null; then cygpath -m "$1"; else printf '%s\n' "$1"; fi
}
script_dir=$(cd "$(dirname "$0")" && pwd)
bootstrap=$(native_path "$script_dir/../windows/bootstrap-wsl.sh")
fixture=$(mktemp -d "${TMPDIR%/}/test-wsl-bootstrap.XXXXXX")
fixture=$(native_path "$fixture")
trap 'rm -rf "$fixture"' EXIT
export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$fixture/gitconfig"
export GIT_ALLOW_PROTOCOL=file GIT_TERMINAL_PROMPT=0
printf '%s\n' '[user]' '  name = WSL bootstrap test' '  email = bootstrap@example.invalid' \
  '[commit]' '  gpgsign = false' '[tag]' '  gpgsign = false' \
  '[core]' '  autocrlf = false' > "$GIT_CONFIG_GLOBAL"
mkdir -p "$fixture/bin" "$fixture/source"
if command -v cygpath >/dev/null; then
  export PATH="$(cygpath -u "$fixture/bin"):$PATH"
else
  export PATH="$fixture/bin:$PATH"
fi
# Stubs are only for provisioning, never Git. Real clones/fetches/merges run below.
cat > "$fixture/bin/ansible-playbook" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == windows.yml ]]
[[ -f "$ANSIBLE_LOG_PATH" ]]
printf 'ansible:%s\n' "$*" >> "$HOME/provision.calls"
STUB
cat > "$fixture/bin/sudo" <<'STUB'
#!/usr/bin/env bash
echo 'Unexpected sudo/package installation during regression test' >&2
exit 99
STUB
chmod +x "$fixture/bin/ansible-playbook" "$fixture/bin/sudo"
# Linux CI may run as root: stub only the uid check, not checkout operations.
cat > "$fixture/bin/id" <<'STUB'
#!/usr/bin/env bash
[[ "$*" == -u ]] || exit 99
printf '1000\n'
STUB
chmod +x "$fixture/bin/id"
git init -q -b main "$fixture/source"
cat > "$fixture/source/bootstrap.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
[[ "$*" == --fixture ]]
[[ "$PWD" == "$(cd "$HOME/dotfiles" && pwd)" ]]
printf 'bootstrap:%s\n' "$*" >> "$HOME/provision.calls"
STUB
printf '%s\n' '---' > "$fixture/source/windows.yml"
git -C "$fixture/source" add bootstrap.sh windows.yml
git -C "$fixture/source" commit -qm initial
initial=$(git -C "$fixture/source" rev-parse HEAD)
git -C "$fixture/source" tag lightweight
git -C "$fixture/source" tag -a annotated -m 'Annotated fixture tag'
origin="$fixture/origin.git"
git clone -q --bare "$fixture/source" "$origin"

new_home() {
  export HOME="$fixture/$1 profile"
  mkdir -p "$HOME"
  checkout="$HOME/dotfiles"
}
run_bootstrap() {
  rm -f "$HOME/provision.calls" "$HOME/git.trace"
  result=0
  GIT_TRACE="$HOME/git.trace" bash "$bootstrap" "$origin" "$1" --fixture > "$HOME/output" 2>&1 || result=$?
}
fail() {
  printf 'FAIL: %s\n' "$*" >&2
  if [[ -f "$HOME/output" ]]; then cat "$HOME/output" >&2; fi
  exit 1
}
assert_success() {
  [[ "$result" == 0 ]] || fail "bootstrap exited $result"
  [[ $(git -C "$checkout" rev-parse HEAD) == "$1" ]] || fail 'unexpected checkout commit'
  [[ -z $(git -C "$checkout" status --porcelain) ]] || fail 'bootstrap dirtied checkout'
  diff -u <(printf '%s\n' 'bootstrap:--fixture' 'ansible:windows.yml') "$HOME/provision.calls" || fail 'provisioning calls differ'
}
assert_no_merge() {
  grep -q 'built-in: git fetch' "$HOME/git.trace" || fail 'rerun did not fetch requested ref'
  if grep -q 'built-in: git merge' "$HOME/git.trace"; then fail 'detached checkout attempted merge'; fi
}

clone_checkout() {
  new_home "$1"
  git -c advice.detachedHead=false clone -q --branch "$2" -- "$origin" "$checkout"
}
assert_rejected() {
  local before_head before_branch before_status before_origin
  before_head=$(git -C "$checkout" rev-parse HEAD)
  before_branch=$(git -C "$checkout" branch --show-current)
  before_status=$(git -C "$checkout" status --porcelain)
  before_origin=$(git -C "$checkout" remote get-url origin)
  run_bootstrap "$1"
  [[ "$result" != 0 ]] || fail 'unsafe checkout was accepted'
  grep -Fq "$2" "$HOME/output" || fail "missing rejection reason: $2"
  [[ ! -e "$HOME/provision.calls" ]] || fail 'rejected checkout ran provisioning'
  [[ $(git -C "$checkout" rev-parse HEAD) == "$before_head" ]] || fail 'rejected checkout moved HEAD'
  [[ $(git -C "$checkout" branch --show-current) == "$before_branch" ]] || fail 'rejected checkout changed branch'
  [[ $(git -C "$checkout" status --porcelain) == "$before_status" ]] || fail 'rejected checkout changed local files'
  [[ $(git -C "$checkout" remote get-url origin) == "$before_origin" ]] || fail 'rejected checkout changed origin'
}

new_home lightweight
run_bootstrap lightweight
assert_success "$initial"
[[ -z $(git -C "$checkout" branch --show-current) ]] || fail 'tag clone should be detached'
printf 'PASS: first tag clone\n'
run_bootstrap lightweight
assert_success "$initial"
assert_no_merge
printf 'PASS: lightweight tag rerun fetches without merging\n'

new_home annotated
run_bootstrap annotated
assert_success "$initial"
[[ $(git -C "$checkout" cat-file -t refs/tags/annotated) == tag ]] || fail 'fixture tag is not annotated'
run_bootstrap annotated
assert_success "$initial"
assert_no_merge
[[ -z $(git -C "$checkout" branch --show-current) ]] || fail 'tag rerun attached HEAD'
printf 'PASS: annotated tag rerun compares peeled commit without merging\n'

new_home branch
run_bootstrap main
assert_success "$initial"
[[ $(git -C "$checkout" branch --show-current) == main ]] || fail 'branch clone should be attached'
printf 'PASS: first branch clone\n'
printf 'upstream change\n' > "$fixture/source/revision.txt"
git -C "$fixture/source" add revision.txt
git -C "$fixture/source" commit -qm 'advance upstream'
advanced=$(git -C "$fixture/source" rev-parse HEAD)
git -C "$fixture/source" tag advanced
git -C "$fixture/source" push -q "$origin" main advanced
run_bootstrap main
assert_success "$advanced"
[[ $(git -C "$checkout" branch --show-current) == main ]] || fail 'fast-forward detached branch'
grep -q 'built-in: git merge --ff-only FETCH_HEAD' "$HOME/git.trace" || fail 'branch did not use fast-forward-only merge'
printf 'PASS: attached branch fast-forwards to fetched commit\n'

clone_checkout detached-ancestor advanced
git -C "$checkout" checkout -q --detach "$initial"
assert_rejected advanced 'is detached at another commit'
assert_no_merge
printf 'PASS: wrong detached ancestor is rejected without fast-forwarding\n'
clone_checkout detached-descendant advanced
assert_rejected lightweight 'is detached at another commit'
assert_no_merge
printf 'PASS: wrong detached descendant is rejected without switching refs\n'

clone_checkout wrong-branch main
git -C "$checkout" checkout -qb other
assert_rejected main 'is on another branch'
printf 'PASS: wrong attached branch is rejected\n'

clone_checkout dirty main
printf 'local edit\n' >> "$checkout/windows.yml"
assert_rejected main 'has local changes'
printf 'PASS: unstaged local changes are rejected\n'
git -C "$checkout" add windows.yml
assert_rejected main 'has local changes'
printf 'PASS: staged local changes are rejected\n'
git -C "$checkout" reset -q --hard HEAD
printf 'untracked\n' > "$checkout/untracked.txt"
assert_rejected main 'has local changes'
[[ $(< "$checkout/untracked.txt") == untracked ]] || fail 'untracked file content changed'
printf 'PASS: untracked local changes are rejected\n'

clone_checkout wrong-origin main
git -C "$checkout" remote set-url origin "$fixture/other-origin.git"
assert_rejected main 'uses a different origin'
printf 'PASS: wrong origin is rejected\n'

clone_checkout divergence main
git -C "$checkout" reset -q --hard "$initial"
printf 'local commit\n' > "$checkout/local.txt"
git -C "$checkout" add local.txt
git -C "$checkout" commit -qm 'divergent local commit'
assert_rejected main 'Not possible to fast-forward'
grep -q 'built-in: git merge --ff-only FETCH_HEAD' "$HOME/git.trace" || fail 'divergence bypassed fast-forward-only merge'
printf 'PASS: divergent branch is rejected without merging or provisioning\n'
printf 'All WSL bootstrap regression tests passed.\n'
