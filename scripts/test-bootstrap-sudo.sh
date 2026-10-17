#!/usr/bin/env bash
# Exercise a copied bootstrap with isolated commands; never run sudo or install packages.
set -euo pipefail
: "${TMPDIR:?Set TMPDIR to a scratch directory before running these tests}"
script_dir=$(cd "$(dirname "$0")" && pwd)
bootstrap="$script_dir/../bootstrap.sh"
fixture=$(mktemp -d "${TMPDIR%/}/test-bootstrap-sudo.XXXXXX")
trap 'rm -rf "$fixture"' EXIT

fail() {
  printf 'FAIL: %s: %s\n' "$case_name" "$*" >&2
  cat "$case_dir/output" >&2
  exit 1
}

new_case() {
  case_name=$1
  case_dir="$fixture/$case_name"
  bin="$case_dir/bin"
  mkdir -p "$bin"
  # A closed PATH prevents a missing fixture from invoking a real package manager.
  ln -s "$(command -v dirname)" "$bin/dirname"
  ln -s "$(command -v grep)" "$bin/grep"
  printf 'ID=ubuntu\nID_LIKE=debian\n' > "$case_dir/os-release"
  # Substitute only absolute platform paths, not bootstrap logic.
  local content
  content=$(< "$bootstrap")
  # Windows checkouts may use CRLF; run the fixture with Linux line endings.
  content=${content//$'\r'/}
  content=${content//\/etc\/os-release/$case_dir/os-release}
  content=${content//\/usr\/bin\/sudo.ws/$bin/sudo.ws}
  content=${content//\/opt\/homebrew\/bin\/brew/$bin/brew}
  content=${content//\/usr\/local\/bin\/brew/$bin/brew}
  printf '%s\n' "$content" > "$case_dir/bootstrap.sh"
  cat > "$bin/sudo" <<'STUB'
#!/bin/bash
set -euo pipefail
implementation=${0##*/}
printf '%s' "$implementation" >> "$CALLS"
printf ' <%s>' "$@" >> "$CALLS"
printf '\n' >> "$CALLS"
if [[ ${1:-} == -n ]]; then
  policy=$DEFAULT_POLICY
  if [[ $implementation == sudo.ws ]]; then policy=$CLASSIC_POLICY; fi
  # Cached auth passes the old probe, but not the timestamp-ignoring -k probe.
  case "$policy:$*" in
    passwordless:*) exit 0 ;;
    cached:'-n true') exit 0 ;;
    *) exit 1 ;;
  esac
fi
# Simulate apt refreshing this implementation's credential cache without sudo.
case "$*" in
  'apt-get update -y') exit 0 ;;
  'apt-get install -y ansible')
    /bin/cp "$PLAYBOOK_STUB" "${0%/*}/ansible-playbook"
    exit 0 ;;
  *) printf 'Unexpected privileged command (not executed)\n' >&2; exit 99 ;;
esac
STUB
  cat > "$case_dir/playbook-stub" <<'STUB'
#!/bin/bash
set -euo pipefail
printf '%s\n' "$@" > "$PLAYBOOK_ARGS"
STUB
  cp "$case_dir/playbook-stub" "$bin/ansible-playbook"
  cat > "$bin/ansible-galaxy" <<'STUB'
#!/bin/bash
[[ "$*" == 'collection list community.general' ]] || exit 99
printf 'community.general 1.0.0\n'
STUB
  cat > "$bin/apt-get" <<'STUB'
#!/bin/bash
printf 'apt-get must only be passed to the sudo stub\n' >&2
exit 99
STUB
  chmod +x "$bin/"* "$case_dir/playbook-stub"
  default_policy=cached
  classic_policy=cached
  os_type=linux-gnu
  : > "$case_dir/calls"
}

run_bootstrap() {
  local result=0
  PATH="$bin" OSTYPE="$os_type" DEFAULT_POLICY="$default_policy" \
    CLASSIC_POLICY="$classic_policy" CALLS="$case_dir/calls" \
    PLAYBOOK_STUB="$case_dir/playbook-stub" PLAYBOOK_ARGS="$case_dir/args" \
    /bin/bash "$case_dir/bootstrap.sh" "$@" > "$case_dir/output" 2>&1 || result=$?
  [[ $result == 0 ]] || fail "bootstrap exited $result"
}

assert_args() {
  diff -u <(printf '%s\n' setup.yml "$@") "$case_dir/args" || fail 'Ansible arguments differ'
}

new_case cached-default
run_bootstrap --tags 'wsl,symlinks'
assert_args -K --tags 'wsl,symlinks'
printf 'PASS: cached sudo credentials still request Ansible -K\n'

new_case classic-needs-auth
cp "$bin/sudo" "$bin/sudo.ws"
classic_policy=auth
run_bootstrap
assert_args -K
diff -u <(printf '%s\n' 'sudo.ws <-n> <-k> <true>') "$case_dir/calls" ||
  fail 'did not probe the classic sudo selected by Ansible'
printf 'PASS: Debian probes classic sudo, not the cached default implementation\n'

new_case classic-apt
cp "$bin/sudo" "$bin/sudo.ws"
rm "$bin/ansible-playbook"
run_bootstrap --tags wsl
assert_args -K --tags wsl
diff -u <(printf '%s\n' 'sudo.ws <apt-get> <update> <-y>' \
  'sudo.ws <apt-get> <install> <-y> <ansible>' 'sudo.ws <-n> <-k> <true>') \
  "$case_dir/calls" || fail 'apt did not use the selected classic sudo'
printf 'PASS: apt and the cache-independent probe use the same classic sudo\n'

new_case passwordless-default
default_policy=passwordless
run_bootstrap --tags 'wsl,symlinks'
assert_args --tags 'wsl,symlinks'
printf 'PASS: genuinely passwordless default sudo skips -K\n'

new_case passwordless-classic
cp "$bin/sudo" "$bin/sudo.ws"
classic_policy=passwordless
run_bootstrap
assert_args
diff -u <(printf '%s\n' 'sudo.ws <-n> <-k> <true>') "$case_dir/calls" ||
  fail 'passwordless classic sudo was not selected'
printf 'PASS: passwordless classic sudo skips -K despite cached default sudo\n'

new_case default-passwordless-classic-cached
cp "$bin/sudo" "$bin/sudo.ws"
default_policy=passwordless
run_bootstrap
assert_args -K
printf 'PASS: classic cached credentials require -K despite passwordless default sudo\n'

new_case nonexecutable-classic
# A symlink into the native filesystem also works when TMPDIR is a DrvFS mount
# without Unix permission metadata (where chmod -x would have no effect).
ln -s /etc/hosts "$bin/sudo.ws"
[[ ! -x "$bin/sudo.ws" ]] || fail 'fixture target unexpectedly executable'
run_bootstrap
assert_args -K
diff -u <(printf '%s\n' 'sudo <-n> <-k> <true>') "$case_dir/calls" ||
  fail 'nonexecutable classic sudo should fall back to default sudo'
printf 'PASS: nonexecutable classic sudo falls back like tasks/become.yml\n'

new_case cached-explicit-args
run_bootstrap --ask-become-pass --extra-vars 'message=two words *' --tags ''
assert_args -K --ask-become-pass --extra-vars 'message=two words *' --tags ''
printf 'PASS: cached credentials preserve explicit flags, whitespace, globs and empty args\n'

new_case passwordless-explicit-args
default_policy=passwordless
run_bootstrap -K --tags wsl
assert_args -K --tags wsl
printf 'PASS: passwordless sudo preserves the user-supplied -K\n'

new_case fallback-apt
rm "$bin/ansible-playbook"
run_bootstrap
assert_args -K
diff -u <(printf '%s\n' 'sudo <apt-get> <update> <-y>' \
  'sudo <apt-get> <install> <-y> <ansible>' 'sudo <-n> <-k> <true>') \
  "$case_dir/calls" || fail 'apt should fall back to default sudo without classic sudo'
printf 'PASS: apt falls back to default sudo when classic sudo is absent\n'

new_case omarchy
printf 'ID=omarchy\nID_LIKE=arch\n' > "$case_dir/os-release"
cp "$bin/sudo" "$bin/sudo.ws"
run_bootstrap
assert_args -K
diff -u <(printf '%s\n' 'sudo <-n> <-k> <true>') "$case_dir/calls" ||
  fail 'Omarchy should not select Debian classic sudo'
printf 'PASS: non-Debian Linux retains default sudo with cache-independent probing\n'

new_case macos
os_type=darwin24
cp "$bin/sudo" "$bin/sudo.ws"
cat > "$bin/brew" <<'STUB'
#!/bin/bash
[[ "$*" == shellenv ]] || exit 99
printf ':\n'
STUB
chmod +x "$bin/brew"
run_bootstrap --tags 'symlinks,fonts' --extra-vars 'message=two words'
assert_args --tags 'symlinks,fonts' --extra-vars 'message=two words'
[[ ! -s "$case_dir/calls" ]] || fail 'macOS must not probe sudo or inject -K'
printf 'PASS: mocked macOS keeps arguments unchanged and never probes sudo\n'
printf 'All bootstrap sudo regression tests passed.\n'
