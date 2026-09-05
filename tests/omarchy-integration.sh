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
omarchy="$tmp/omarchy"
mock_bin="$tmp/bin"
mkdir -p "$omarchy" "$mock_bin"
cp -R "$repo/tests/fixtures/omarchy/default" "$omarchy/default"
cp "$repo/tests/fixtures/omarchy/bin/omarchy" "$mock_bin/omarchy"
chmod +x "$mock_bin/omarchy"
: > "$tmp/present"
: > "$tmp/calls"

snapshot="$tmp/omarchy.before"
find "$omarchy" -mindepth 1 -printf '%P %y %l\n' | LC_ALL=C sort > "$snapshot"

run_config() {
  ansible-playbook "$repo/setup.yml" -i localhost, -c local \
    -e ansible_distribution=Omarchy \
    -e ansible_os_family=Archlinux \
    -e home="$home" \
    -e omarchy_path="$omarchy" \
    -e omarchy_command="$mock_bin/omarchy" \
    -e "omarchy_zsh_enabled=$zsh_enabled" \
    -e "omarchy_yazi_enabled=$yazi_enabled" \
    "$@"
}

assert_paths() {
  local expected=$1 actual="$tmp/actual-paths"
  find "$home" -mindepth 1 -printf '%P\n' | LC_ALL=C sort > "$actual"
  diff -u "$expected" "$actual"
}

# Both selected: all five managed targets, then a no-op second run.
home="$tmp/both-home"
zsh_enabled=true
yazi_enabled=true
mkdir "$home"
printf '%s\n' .config .config/dotfiles .config/dotfiles/starship.toml \
  .config/dotfiles/zsh .config/dotfiles/zsh/personal.zsh .config/yazi \
  .zprofile .zshrc | LC_ALL=C sort > "$tmp/both-expected"
run_config --tags omarchy_config > "$tmp/both-run1.log"
run_config --tags omarchy_config | tee "$tmp/both-run2.log"
grep -E 'changed=0 ' "$tmp/both-run2.log"
assert_paths "$tmp/both-expected"
cmp "$repo/omarchy/zsh/.zshrc" "$home/.zshrc"
cmp "$repo/omarchy/zsh/.zprofile" "$home/.zprofile"
[[ $(readlink "$home/.config/dotfiles/starship.toml") == "$repo/.config/starship.toml" ]]
[[ $(readlink "$home/.config/dotfiles/zsh/personal.zsh") == "$repo/omarchy/zsh/personal.zsh" ]]
[[ $(readlink "$home/.config/yazi") == "$repo/.config/yazi" ]]
[[ ! -e "$home/.config/starship.toml" ]]

# Zsh-only, Yazi-only, and no-component config runs create exact subsets.
home="$tmp/zsh-home"
zsh_enabled=true
yazi_enabled=false
mkdir "$home"
printf '%s\n' .config .config/dotfiles .config/dotfiles/starship.toml \
  .config/dotfiles/zsh .config/dotfiles/zsh/personal.zsh .zprofile .zshrc |
  LC_ALL=C sort > "$tmp/zsh-expected"
run_config --tags omarchy_config > "$tmp/zsh-run1.log"
run_config --tags omarchy_config > "$tmp/zsh-run2.log"
grep -E 'changed=0 ' "$tmp/zsh-run2.log"
assert_paths "$tmp/zsh-expected"

home="$tmp/yazi-home"
zsh_enabled=false
yazi_enabled=true
mkdir "$home"
printf '%s\n' .config .config/yazi | LC_ALL=C sort > "$tmp/yazi-expected"
run_config --tags omarchy_config > "$tmp/yazi-run1.log"
run_config --tags omarchy_config > "$tmp/yazi-run2.log"
grep -E 'changed=0 ' "$tmp/yazi-run2.log"
assert_paths "$tmp/yazi-expected"

home="$tmp/none-home"
zsh_enabled=false
yazi_enabled=false
mkdir "$home"
: > "$tmp/none-expected"
run_config --tags omarchy_config > "$tmp/none-run1.log"
run_config --tags omarchy_config > "$tmp/none-run2.log"
grep -E 'changed=0 ' "$tmp/none-run2.log"
assert_paths "$tmp/none-expected"

# Existing targets are backed up under the explicitly supplied rollback root.
home="$tmp/conflict-home"
zsh_enabled=true
yazi_enabled=true
backup="$tmp/rollback"
mkdir -p "$home/.config/dotfiles/zsh" "$home/.config/yazi"
printf 'old-zshrc\n' > "$home/.zshrc"
printf 'old-zprofile\n' > "$home/.zprofile"
printf 'old-personal\n' > "$home/.config/dotfiles/zsh/personal.zsh"
printf 'old-starship\n' > "$home/.config/dotfiles/starship.toml"
printf 'old-yazi\n' > "$home/.config/yazi/marker"
run_config -e backup_dir="$backup" --tags omarchy_config > "$tmp/backup-run1.log"
run_config -e backup_dir="$backup" --tags omarchy_config > "$tmp/backup-run2.log"
grep -E 'changed=0 ' "$tmp/backup-run2.log"
[[ $(<"$backup/.zshrc.bak") == old-zshrc ]]
[[ $(<"$backup/.zprofile.bak") == old-zprofile ]]
[[ $(<"$backup/.config_dotfiles_zsh_personal.zsh.bak") == old-personal ]]
[[ $(<"$backup/.config_dotfiles_starship.toml.bak") == old-starship ]]
[[ $(<"$backup/.config_yazi.bak/marker") == old-yazi ]]

# The Omarchy source fixture is input-only.
find "$omarchy" -mindepth 1 -printf '%P %y %l\n' | LC_ALL=C sort > "$tmp/omarchy.after"
cmp "$snapshot" "$tmp/omarchy.after"

# Untagged Omarchy and an Omarchy tag on synthetic Debian both change nothing.
legacy_home="$tmp/legacy-home"
mkdir "$legacy_home"
ansible-playbook "$repo/setup.yml" -i localhost, -c local \
  -e ansible_distribution=Omarchy -e ansible_os_family=Archlinux \
  -e home="$legacy_home" -e omarchy_path="$omarchy" \
  -e omarchy_command="$mock_bin/omarchy" > "$tmp/untagged.log"
grep -E 'changed=0 ' "$tmp/untagged.log"
[[ -z $(find "$legacy_home" -mindepth 1 -print -quit) ]]

debian_home="$tmp/debian-home"
mkdir "$debian_home"
ansible-playbook "$repo/setup.yml" -i localhost, -c local \
  -e ansible_distribution=Ubuntu -e ansible_os_family=Debian \
  -e home="$debian_home" --tags omarchy_config > "$tmp/debian.log"
grep -E 'changed=0 ' "$tmp/debian.log"
[[ -z $(find "$debian_home" -mindepth 1 -print -quit) ]]

printf 'Omarchy disposable-HOME integration checks passed\n'
