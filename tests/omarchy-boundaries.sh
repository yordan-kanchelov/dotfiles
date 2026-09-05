#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_file() { [[ -f "$repo/$1" ]] || fail "missing $1"; }
require_text() {
  local file=$1 text=$2
  grep -Fq -- "$text" "$repo/$file" || fail "$file missing: $text"
}
forbid_text() {
  local file=$1 pattern=$2
  ! grep -Eq -- "$pattern" "$repo/$file" || fail "$file contains prohibited pattern: $pattern"
}

for file in bootstrap.sh install-omarchy.sh vars/Omarchy.yml tasks/omarchy.yml \
  omarchy/zsh/.zshrc omarchy/zsh/.zprofile omarchy/zsh/personal.zsh \
  tests/omarchy-integration.sh tests/omarchy-installer.sh; do
  require_file "$file"
done
[[ -x "$repo/install-omarchy.sh" ]] || fail 'install-omarchy.sh must be executable'

# Ansible's Omarchy path is config-only and never-tagged.
forbid_text vars/Omarchy.yml '^omarchy_packages:'
forbid_text tasks/omarchy.yml 'pkg.*(present|add)|omarchy_packages|omarchy_package'
forbid_text setup.yml 'omarchy_packages'
require_text setup.yml 'Omarchy config adapter'
require_text setup.yml 'tags: [omarchy_config, never]'
forbid_text setup.yml 'tags: \[omarchy, never\]'
require_text tasks/omarchy.yml 'tags: [omarchy_config, never]'
require_text tasks/omarchy.yml 'when: omarchy_zsh_enabled | bool'
require_text vars/Omarchy.yml 'enabled: "{{ omarchy_yazi_enabled | bool }}"'
if grep -Fq 'omarchy_packages' "$repo/tasks/omarchy.yml" "$repo/vars/Omarchy.yml" "$repo/setup.yml"; then
  fail 'Ansible still exposes the removed omarchy_packages interface'
fi

# The installer's complete fixed catalog and public package route are explicit.
require_text install-omarchy.sh 'catalog=(omarchy-zsh yazi shellcheck git-lfs glow viu act pandoc-cli fnm)'
# Match source variable references literally, not this test's variables.
# shellcheck disable=SC2016
require_text install-omarchy.sh 'validate_csv "$components_csv" components zsh yazi'
# Match the literal optional-tools validation call in the source.
# shellcheck disable=SC2016
require_text install-omarchy.sh 'validate_csv "$optional_csv" optional-tools shellcheck git-lfs glow viu act pandoc-cli'
# Match the source array expansion without expanding it in this test.
# shellcheck disable=SC2016
require_text install-omarchy.sh 'run_recorded omarchy pkg add "${queued[@]}"'
require_text install-omarchy.sh 'omarchy install dev-env node'
require_text install-omarchy.sh 'omarchy-base.packages'
require_text install-omarchy.sh 'omarchy-install.receipt'
require_text install-omarchy.sh '--non-interactive'
require_text install-omarchy.sh '--dry-run'
require_text install-omarchy.sh '--backup-dir'
require_text install-omarchy.sh "confirm --default=false 'Apply this plan?'"

for file in bootstrap.sh install-omarchy.sh tasks/omarchy.yml vars/Omarchy.yml; do
  forbid_text "$file" 'pkg[[:space:]]+aur|pacman[[:space:]]+-S|(^|[^[:alnum:]_-])(yay|paru)([^[:alnum:]_-]|$)|omarchy[[:space:]]+update|pkg[[:space:]]+(drop|remove)'
done
for deferred in aws aws-cli ollama ghostty hadolint k6 grpcurl ghz atuin sheldon; do
  forbid_text install-omarchy.sh "(^|[^[:alnum:]_-])$deferred([^[:alnum:]_-]|$)"
done
forbid_text install-omarchy.sh 'arbitrary|passthrough|dev-env[[:space:]]+(python|go|rust|java)'

# Bootstrap owns only the Omarchy Ansible prerequisite and never dispatches setup on that branch.
# Match the bootstrap source condition, not the test environment's OS.
# shellcheck disable=SC2016
require_text bootstrap.sh '[[ $os_id == omarchy ]]'
require_text bootstrap.sh 'omarchy pkg add ansible'
require_text bootstrap.sh 'Prerequisites ready. Next: ./install-omarchy.sh'
require_text bootstrap.sh '(($# == 0))'

# Managed HOME paths stay exactly within the original five-path contract.
mapfile -t managed_paths < <(awk '/^    dest: / { sub(/^    dest: /, ""); print }' "$repo/vars/Omarchy.yml")
expected_paths=(
  .config/dotfiles/zsh/personal.zsh
  .config/dotfiles/starship.toml
  .config/yazi
)
[[ ${managed_paths[*]} == "${expected_paths[*]}" ]] ||
  fail 'Omarchy managed-path allowlist changed'
for forbidden in hypr/hyprland.lua hypr/bindings.lua omarchy/shell.json foot/foot.ini \
  ghostty/config .config/nvim .config/tmux .tmux.conf .config/atuin .config/sheldon fonts/; do
  if grep -FRq -- "$forbidden" "$repo/vars/Omarchy.yml" "$repo/tasks/omarchy.yml" "$repo/omarchy"; then
    fail "forbidden Omarchy-managed path: $forbidden"
  fi
done
if awk '/^[[:space:]]+dest:/ && $0 !~ /{{ home }}\// { print; bad=1 } END { exit bad ? 0 : 1 }' \
  "$repo/tasks/omarchy.yml" | grep -q .; then
  fail 'every Omarchy task destination must begin with {{ home }}/'
fi

# Legacy platform gates and the defensive desktop assertion remain.
require_text setup.yml 'is_omarchy: "{{ (ansible_distribution | lower) == '\''omarchy'\'' }}"'
require_text setup.yml "is_legacy_platform: \"{{ ansible_os_family in ['Darwin', 'Debian'] and not is_omarchy }}\""
require_text setup.yml "vars/{{ 'Omarchy' if is_omarchy else ansible_os_family }}.yml"
require_text setup.yml 'when: is_legacy_platform'
require_text setup.yml "when: ansible_os_family == 'Debian' and not is_omarchy"
require_text tasks/desktop.yml "ansible_os_family == 'Debian'"
require_text tasks/desktop.yml 'not is_omarchy'

# Official loaders stay ahead of personal code and fnm is gated by inactive Mise Node.
zshrc="$repo/omarchy/zsh/.zshrc"
# These searches intentionally match literal Zsh variable references.
# shellcheck disable=SC2016
zoptions_line=$(grep -nF 'source "$omarchy_zsh_root/shell/zoptions"' "$zshrc" | cut -d: -f1)
# shellcheck disable=SC2016
all_line=$(grep -nF 'source "$omarchy_zsh_root/shell/all"' "$zshrc" | cut -d: -f1)
# shellcheck disable=SC2016
personal_line=$(grep -nF 'source "$HOME/.config/dotfiles/zsh/personal.zsh"' "$zshrc" | cut -d: -f1)
[[ -n $zoptions_line && -n $all_line && -n $personal_line ]] || fail 'incomplete Omarchy Zsh loader chain'
(( zoptions_line < all_line && all_line < personal_line )) || fail 'personal code loads before official loaders'
# shellcheck disable=SC2016
require_text omarchy/zsh/.zshrc 'export STARSHIP_CONFIG="$HOME/.config/dotfiles/starship.toml"'
require_text omarchy/zsh/personal.zsh 'if (( $+commands[fnm] )) && ! mise where node >/dev/null 2>&1; then'
# Match the Zsh source command substitution without executing fnm here.
# shellcheck disable=SC2016
require_text omarchy/zsh/personal.zsh 'eval "$(fnm env --use-on-cd --shell zsh)"'
forbid_text omarchy/zsh/personal.zsh '^eval .*fnm env'
forbid_text omarchy/zsh/personal.zsh 'atuin|sheldon|starship init|zoxide init|fzf --zsh'

# CI and docs exercise the split bootstrap/installer flow.
require_text .github/workflows/test-setup-ci.yml 'bash tests/omarchy-installer.sh'
require_text .github/workflows/test-setup-ci.yml 'install-omarchy.sh'
require_text README.md './install-omarchy.sh --non-interactive --yes'
for tool in git-lfs glow viu act pandoc-cli; do
  require_text README.md "\`$tool\`"
done
require_text README.md 'omarchy-install.receipt'

printf 'Omarchy boundary checks passed\n'
