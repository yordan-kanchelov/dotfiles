#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
[[ -x "$repo/install-omarchy.sh" ]] || fail 'install-omarchy.sh is missing or not executable'

new_case() {
  case_root="$tmp/$1"
  case_home="$case_root/home"
  case_bin="$case_root/bin"
  case_omarchy="$case_root/omarchy"
  case_backup="$case_home/.dotfiles_backup/run"
  mkdir -p "$case_home" "$case_bin" "$case_omarchy/default/hypr" "$case_omarchy/install"
  cp "$repo/tests/fixtures/omarchy/bin/omarchy" "$case_bin/omarchy"
  cp "$repo/tests/fixtures/omarchy/bin/mise" "$case_bin/mise"
  cp "$repo/tests/fixtures/omarchy/bin/gum" "$case_bin/gum"
  cp "$repo/tests/fixtures/omarchy/bin/ansible-galaxy" "$case_bin/ansible-galaxy"
  cp "$repo/tests/fixtures/omarchy/bin/ansible-playbook.mock" "$case_bin/ansible-playbook"
  cp "$repo/tests/fixtures/omarchy/bin/ansible-playbook.mock" "$case_bin/.ansible-playbook.mock"
  chmod +x "$case_bin"/* "$case_bin"/.ansible-playbook.mock
  # CI tools must not leak into prerequisite-availability tests.
  for utility in bash dirname grep awk realpath date git mkdir cp chmod sed cat tr; do
    ln -s "$(command -v "$utility")" "$case_bin/$utility"
  done
  : > "$case_root/present"
  : > "$case_root/calls"
  : > "$case_root/gum-calls"
  : > "$case_root/ansible-calls"
  : > "$case_omarchy/install/omarchy-base.packages"
  printf '%s\n' 'ID=omarchy' > "$case_root/os-release"
  touch "$case_omarchy/default/hypr/bootstrap.lua"
}

run_installer() {
  set +e
  PATH="$case_bin" HOME="$case_home" OSTYPE=linux-gnu \
    DOTFILES_OS_RELEASE="$case_root/os-release" OMARCHY_PATH="$case_omarchy" \
    DOTFILES_GUM="$case_bin/gum" DOTFILES_MOCK_ROOT="$case_root" \
    "$repo/install-omarchy.sh" "$@" </dev/null > "$case_root/output" 2>&1
  run_rc=$?
  set -e
}

run_bootstrap() {
  # Only expose the utilities used by bootstrap and its fixtures. Falling back
  # to /usr/bin or /bin would expose CI's Ansible in the missing-tool case.
  local utility
  for utility in bash dirname grep cp chmod; do
    [[ -e $case_bin/$utility ]] || ln -s "$(command -v "$utility")" "$case_bin/$utility"
  done
  bootstrap_ansible_before=$(PATH="$case_bin" command -v ansible-playbook || true)
  set +e
  PATH="$case_bin" HOME="$case_home" OSTYPE=linux-gnu \
    DOTFILES_OS_RELEASE="$case_root/os-release" OMARCHY_PATH="$case_omarchy" \
    DOTFILES_MOCK_ROOT="$case_root" "$repo/bootstrap.sh" "$@" </dev/null \
    > "$case_root/output" 2>&1
  run_rc=$?
  set -e
  bootstrap_ansible_after=$(PATH="$case_bin" command -v ansible-playbook || true)
  printf 'Bootstrap Ansible resolution: before=%s after=%s\n' \
    "${bootstrap_ansible_before:-absent}" "${bootstrap_ansible_after:-absent}"
}

assert_contains() { grep -Fq -- "$2" "$1" || fail "$1 missing: $2"; }

assert_no_mutation() {
  ! grep -Eq '^(pkg add|install dev-env|fnm (install|default) )' "$case_root/calls" ||
    fail "$1 mutated"
  [[ ! -e "$case_backup/omarchy-install.receipt" ]] || fail "$1 wrote a receipt"
}

# Bootstrap: missing Ansible uses exactly one public package call and never runs setup.yml.
new_case bootstrap-missing
rm "$case_bin/ansible-playbook"
run_bootstrap
[[ $run_rc -eq 0 ]] || fail 'bootstrap with missing Ansible failed'
[[ -z $bootstrap_ansible_before ]] || fail 'missing-Ansible case exposed an executable'
[[ $bootstrap_ansible_after == "$case_bin/ansible-playbook" ]] || fail 'bootstrap did not resolve installed fixture'
[[ $(grep -c '^pkg add ansible$' "$case_root/calls") -eq 1 ]] || fail 'bootstrap did not add only Ansible once'
grep -Fq 'Prerequisites ready. Next: ./install-omarchy.sh' "$case_root/output"
[[ ! -s "$case_root/ansible-calls" ]] || fail 'Omarchy bootstrap ran setup.yml'

new_case bootstrap-present
run_bootstrap
[[ $run_rc -eq 0 ]] || fail 'bootstrap with present Ansible failed'
[[ $bootstrap_ansible_before == "$case_bin/ansible-playbook" ]] || fail 'present-Ansible case did not resolve fixture'
[[ $bootstrap_ansible_after == "$bootstrap_ansible_before" ]] || fail 'present-Ansible resolution changed'
! grep -q '^pkg add ' "$case_root/calls" || fail 'bootstrap reinstalled Ansible'
[[ ! -s "$case_root/ansible-calls" ]] || fail 'Omarchy bootstrap ran setup.yml'

new_case bootstrap-args
run_bootstrap --tags omarchy
[[ $run_rc -ne 0 ]] || fail 'Omarchy bootstrap accepted arguments'
assert_no_mutation bootstrap-args

new_case bootstrap-unknown
printf '%s\n' 'ID=arch' > "$case_root/os-release"
run_bootstrap
[[ $run_rc -ne 0 ]] || fail 'unknown Linux bootstrap succeeded'
assert_no_mutation bootstrap-unknown

new_case bootstrap-marker-missing
rm "$case_omarchy/default/hypr/bootstrap.lua"
run_bootstrap
[[ $run_rc -ne 0 ]] || fail 'Omarchy bootstrap accepted a missing marker'
assert_no_mutation bootstrap-marker-missing

# Non-interactive defaults: exact package batch, existing Mise Node preserved, config applied.
new_case defaults
printf '%s\n' '/mock/mise/installs/node/26.8.1' > "$case_root/mise-node"
run_installer --non-interactive --yes --backup-dir "$case_backup"
[[ $run_rc -eq 0 ]] || fail 'default non-interactive install failed'
[[ $(grep -c '^pkg add ' "$case_root/calls") -eq 1 ]] || fail 'default plan did not use one package batch'
grep -Fxq 'pkg add yazi shellcheck' "$case_root/calls"
! grep -q '^install dev-env node$' "$case_root/calls" || fail 'active Mise Node was changed'
[[ ! -s "$case_root/gum-calls" ]] || fail 'non-interactive run called Gum'
grep -Fq -- '--tags omarchy_config' "$case_root/ansible-calls"
grep -Fq 'omarchy_bash_enabled=true' "$case_root/ansible-calls"
grep -Fq 'omarchy_yazi_enabled=true' "$case_root/ansible-calls"
receipt="$case_backup/omarchy-install.receipt"
[[ -f $receipt ]] || fail 'default run did not write receipt'
grep -Fq 'components: bash,yazi' "$receipt"
grep -Fq 'optional-tools: shellcheck' "$receipt"
grep -Fq 'runtime: KEEP' "$receipt"

: > "$case_root/calls"
run_installer --non-interactive --yes --backup-dir "$case_home/.dotfiles_backup/run2"
[[ $run_rc -eq 0 ]] || fail 'second identical run failed'
! grep -q '^pkg add ' "$case_root/calls" || fail 'second identical run added packages'

# Stable optional order, base ownership, and present-package skips.
new_case optional-order
printf '%s\n' '/mock/mise/installs/node/26.8.1' > "$case_root/mise-node"
run_installer --non-interactive --yes --components none \
  --optional-tools viu,glow,git-lfs --config no \
  --backup-dir "$case_backup"
[[ $run_rc -eq 0 ]] || fail 'optional-tool run failed'
grep -Fxq 'pkg add git-lfs glow viu' "$case_root/calls"
[[ ! -s "$case_root/ansible-calls" ]] || fail 'config=no ran Ansible'

new_case package-skips
printf '%s\n' '/mock/mise/installs/node/26.8.1' > "$case_root/mise-node"
printf '%s\n' 'yazi' > "$case_omarchy/install/omarchy-base.packages"
printf '%s\n' yazi shellcheck > "$case_root/present"
run_installer --non-interactive --yes --backup-dir "$case_backup"
[[ $run_rc -eq 0 ]] || fail 'base/present skip run failed'
! grep -q '^pkg add ' "$case_root/calls" || fail 'already-present plan installed packages'
grep -Fq 'base-owned: yazi' "$case_root/output"
grep -Fq 'already-present: shellcheck' "$case_root/output"

# Dry-run and invalid input must stop before every mutation and receipt.
new_case dry-run
printf '%s\n' '/mock/mise/installs/node/26.8.1' > "$case_root/mise-node"
run_installer --non-interactive --dry-run --backup-dir "$case_backup"
[[ $run_rc -eq 0 ]] || fail 'dry-run failed'
assert_no_mutation dry-run
[[ ! -s "$case_root/ansible-calls" ]] || fail 'dry-run executed Ansible'
grep -Fq -- '--check --diff' "$case_root/output"


new_case missing-yes
printf '%s\n' '/mock/mise/installs/node/26.8.1' > "$case_root/mise-node"
run_installer --non-interactive --backup-dir "$case_backup"
[[ $run_rc -ne 0 ]] || fail 'mutating non-interactive run omitted --yes but succeeded'
assert_no_mutation missing-yes

new_case installer-ansible-missing
rm "$case_bin/ansible-playbook"
run_installer --non-interactive --yes --backup-dir "$case_backup"
[[ $run_rc -ne 0 ]] || fail 'installer accepted missing Ansible prerequisite'
assert_no_mutation installer-ansible-missing

new_case installer-gum-missing
rm "$case_bin/gum"
run_installer --backup-dir "$case_backup"
[[ $run_rc -ne 0 ]] || fail 'interactive installer accepted missing Gum'
assert_no_mutation installer-gum-missing

for invalid in '--unknown' '--components bash,bad' '--components zsh' '--optional-tools shellcheck,bad' \
  '--node-manager bad' '--config maybe' '--backup-dir relative' 'positional'; do
  new_case "invalid-${invalid//[^a-zA-Z0-9]/-}"
  printf '%s\n' '/mock/mise/installs/node/26.8.1' > "$case_root/mise-node"
  # Deliberately split each compact invalid test vector.
  # shellcheck disable=SC2086
  run_installer --non-interactive --yes $invalid
  [[ $run_rc -ne 0 ]] || fail "invalid input succeeded: $invalid"
  assert_no_mutation "invalid input $invalid"
done

# Runtime is KEEP even with no available Mise Node.
new_case runtime-keep
run_installer --non-interactive --yes --config no --backup-dir "$case_backup"
[[ $run_rc -eq 0 ]] || fail 'missing runtime blocked installation'
! grep -Eq '^(mise|fnm|install dev-env)' "$case_root/calls" || fail 'runtime was probed or changed'

# Interactive accepted defaults and cancellation at every prompt.
new_case gum-defaults
printf '%s\n' '/mock/mise/installs/node/26.8.1' > "$case_root/mise-node"
printf '%s\n' 'Bash shortcuts + vi;Yazi' 'ShellCheck' yes yes > "$case_root/gum-responses"
run_installer --backup-dir "$case_backup"
[[ $run_rc -eq 0 ]] || { printf '%s\n' '--- interactive output ---' >&2; command cat "$case_root/output" >&2; fail 'interactive defaults failed'; }
grep -Fxq 'pkg add yazi shellcheck' "$case_root/calls"
[[ $(wc -l < "$case_root/gum-calls") -eq 4 ]] || fail 'interactive defaults used the wrong prompt count'
assert_contains "$case_root/output" "Target: $case_root/omarchy"
assert_contains "$case_root/output" 'Runtime: KEEP'

cancel_prefixes=(
  '__CANCEL__'
  'Bash shortcuts + vi;Yazi|__CANCEL__'
  'Bash shortcuts + vi;Yazi|ShellCheck|__CANCEL__'
  'Bash shortcuts + vi;Yazi|ShellCheck|yes|__CANCEL__'
)
index=0
for responses in "${cancel_prefixes[@]}"; do
  new_case "gum-cancel-$index"
  printf '%s\n' '/mock/mise/installs/node/26.8.1' > "$case_root/mise-node"
  tr '|' '\n' <<< "$responses" > "$case_root/gum-responses"
  run_installer --backup-dir "$case_backup"
  [[ $run_rc -ne 0 ]] || fail "Gum cancel $index succeeded"
  assert_no_mutation "Gum cancel $index"
  index=$((index + 1))
done


# Ownership mismatches and invalid backup/duplicate options fail before mutation.
new_case base-missing
printf 'shellcheck\n' > "$case_root/omarchy/install/omarchy-base.packages"
printf '%s\n' '/mock/mise/installs/node/26.8.1' > "$case_root/mise-node"
run_installer --non-interactive --yes
[[ $run_rc -ne 0 ]] || fail 'absent base-owned package was accepted'
assert_no_mutation base-missing
[[ ! -d $case_home/.dotfiles_backup ]] || fail 'ownership mismatch wrote a receipt'

new_case invalid-options
run_installer --non-interactive --yes --config yes --config no
[[ $run_rc -ne 0 ]] || fail 'conflicting duplicate option was accepted'
assert_no_mutation invalid-options
run_installer --non-interactive --yes --backup-dir "$tmp/outside"
[[ $run_rc -ne 0 ]] || fail 'backup directory outside HOME was accepted'
assert_no_mutation invalid-backup

# Package failure is receipted and stops Node/config execution.
new_case package-failure
touch "$case_root/fail-add"
run_installer --non-interactive --yes --backup-dir "$case_home/.dotfiles_backup/failure"
[[ $run_rc -ne 0 ]] || fail 'package failure was ignored'
assert_contains "$case_home/.dotfiles_backup/failure/omarchy-install.receipt" 'status: 17'
! grep -q '^install dev-env node$' "$case_root/calls" || fail 'Node ran after package failure'
[[ ! -s $case_root/ansible-calls ]] || fail 'Ansible ran after package failure'

new_case backup-symlink
mkdir "$case_root/outside"
ln -s "$case_root/outside" "$case_home/.dotfiles_backup"
run_installer --non-interactive --yes
[[ $run_rc -ne 0 ]] || fail 'symlinked backup root was accepted'
[[ -z $(find "$case_root/outside" -mindepth 1 -print -quit) ]] || fail 'backup escaped HOME'

printf 'Omarchy installer checks passed\n'
