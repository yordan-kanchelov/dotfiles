#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
if ! command -v ansible-playbook >/dev/null; then
  if [[ ${REQUIRE_ANSIBLE:-0} == 1 ]]; then
    printf 'ansible-playbook is required\n' >&2
    exit 1
  fi
  printf 'SKIP: ansible-playbook is unavailable\n'
  exit 0
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
omarchy="$tmp/omarchy"
omarchy_zsh="$tmp/omarchy-zsh"
mock_bin="$tmp/bin"
mkdir -p "$home" "$omarchy" "$omarchy_zsh" "$mock_bin"
cp -R "$repo/tests/fixtures/omarchy/default" "$omarchy/default"
cp -R "$repo/tests/fixtures/omarchy-zsh/shell" "$omarchy_zsh/shell"
cp "$repo/tests/fixtures/omarchy/bin/omarchy" "$mock_bin/omarchy"
chmod +x "$mock_bin/omarchy"
touch "$mock_bin/present" "$mock_bin/calls"

snapshot="$tmp/omarchy.before"
find "$omarchy" -mindepth 1 -printf '%P %y %l\n' | LC_ALL=C sort > "$snapshot"

run_omarchy() {
  ansible-playbook "$repo/setup.yml" -i localhost, -c local \
    -e ansible_distribution=Omarchy \
    -e ansible_os_family=Archlinux \
    -e home="$home" \
    -e omarchy_path="$omarchy" \
    -e omarchy_command="$mock_bin/omarchy" \
    -e omarchy_become=false \
    "$@"
}

run_omarchy --tags omarchy_config > "$tmp/config-run1.log"
run_omarchy --tags omarchy_config | tee "$tmp/config-run2.log"
grep -E 'changed=0 ' "$tmp/config-run2.log"

expected_paths="$tmp/expected-paths"
actual_paths="$tmp/actual-paths"
printf '%s\n' \
  .config \
  .config/dotfiles \
  .config/dotfiles/starship.toml \
  .config/dotfiles/zsh \
  .config/dotfiles/zsh/personal.zsh \
  .config/yazi \
  .zprofile \
  .zshrc | LC_ALL=C sort > "$expected_paths"
find "$home" -mindepth 1 -printf '%P\n' | LC_ALL=C sort > "$actual_paths"
diff -u "$expected_paths" "$actual_paths"
cmp "$repo/omarchy/zsh/.zshrc" "$home/.zshrc"
cmp "$repo/omarchy/zsh/.zprofile" "$home/.zprofile"
[[ $(readlink "$home/.config/dotfiles/starship.toml") == "$repo/.config/starship.toml" ]]
[[ $(readlink "$home/.config/dotfiles/zsh/personal.zsh") == "$repo/omarchy/zsh/personal.zsh" ]]
[[ $(readlink "$home/.config/yazi") == "$repo/.config/yazi" ]]
[[ ! -e "$home/.config/starship.toml" ]]
grep -Fq 'OMARCHY_PATH:-/usr/share/omarchy' "$home/.zshrc"
grep -Fq 'OMARCHY_ZSH_PATH:-/usr/share/omarchy-zsh' "$home/.zshrc"
find "$omarchy" -mindepth 1 -printf '%P %y %l\n' | LC_ALL=C sort > "$tmp/omarchy.after"
cmp "$snapshot" "$tmp/omarchy.after"

clean_home=$home
home="$tmp/conflict-home"
backup="$tmp/rollback"
mkdir -p "$home/.config/dotfiles/zsh" "$home/.config/yazi"
printf 'old-zshrc\n' > "$home/.zshrc"
printf 'old-zprofile\n' > "$home/.zprofile"
printf 'old-personal\n' > "$home/.config/dotfiles/zsh/personal.zsh"
printf 'old-starship\n' > "$home/.config/dotfiles/starship.toml"
printf 'old-yazi\n' > "$home/.config/yazi/marker"
run_omarchy -e backup_dir="$backup" --tags omarchy_config > "$tmp/backup-run1.log"
run_omarchy -e backup_dir="$backup" --tags omarchy_config > "$tmp/backup-run2.log"
grep -E 'changed=0 ' "$tmp/backup-run2.log"
[[ $(<"$backup/.zshrc.bak") == old-zshrc ]]
[[ $(<"$backup/.zprofile.bak") == old-zprofile ]]
[[ $(<"$backup/.config_dotfiles_zsh_personal.zsh.bak") == old-personal ]]
[[ $(<"$backup/.config_dotfiles_starship.toml.bak") == old-starship ]]
[[ $(<"$backup/.config_yazi.bak/marker") == old-yazi ]]
home=$clean_home

legacy_home="$tmp/legacy-home"
mkdir "$legacy_home"
ansible-playbook "$repo/setup.yml" -i localhost, -c local \
  -e ansible_distribution=Omarchy \
  -e ansible_os_family=Archlinux \
  -e home="$legacy_home" \
  -e omarchy_path="$omarchy" \
  -e omarchy_command="$mock_bin/omarchy" > "$tmp/untagged.log"
grep -E 'changed=0 ' "$tmp/untagged.log"
[[ -z $(find "$legacy_home" -mindepth 1 -print -quit) ]]

debian_home="$tmp/debian-home"
mkdir "$debian_home"
ansible-playbook "$repo/setup.yml" -i localhost, -c local \
  -e ansible_distribution=Ubuntu \
  -e ansible_os_family=Debian \
  -e home="$debian_home" \
  --tags omarchy_config > "$tmp/debian.log"
grep -E 'changed=0 ' "$tmp/debian.log"
[[ -z $(find "$debian_home" -mindepth 1 -print -quit) ]]

printf '%s\n' omarchy-zsh yazi > "$mock_bin/present"
: > "$mock_bin/calls"
run_omarchy --tags omarchy_packages > "$tmp/packages-present.log"
grep -E 'changed=0 ' "$tmp/packages-present.log"
[[ ! -s "$mock_bin/calls" ]]

: > "$mock_bin/present"
: > "$mock_bin/calls"
run_omarchy --tags omarchy_packages > "$tmp/packages-missing.log"
[[ $(wc -l < "$mock_bin/calls") -eq 1 ]]
grep -Fxq 'add omarchy-zsh yazi' "$mock_bin/calls"
run_omarchy --tags omarchy_packages > "$tmp/packages-run2.log"
grep -E 'changed=0 ' "$tmp/packages-run2.log"

printf 'Omarchy disposable-HOME integration checks passed\n'
