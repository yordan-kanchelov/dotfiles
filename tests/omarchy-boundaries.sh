#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fail() { printf 'FAIL: %s\n' "$*" >&2; exit 1; }
require_file() { [[ -f "$repo/$1" ]] || fail "missing $1"; }
require_text() {
  local file=$1 text=$2
  grep -Fq -- "$text" "$repo/$file" || fail "$file missing: $text"
}

for file in vars/Omarchy.yml tasks/omarchy.yml omarchy/zsh/.zshrc \
  omarchy/zsh/.zprofile omarchy/zsh/personal.zsh tests/omarchy-integration.sh; do
  require_file "$file"
done

if grep -ERiq --include='*.yml' \
  'pacman[[:space:]]+-S(yu|yyu)|(^|[^[:alnum:]_-])(yay|paru)([^[:alnum:]_-]|$)|omarchy[[:space:]]+update|omarchy-setup-zsh|(^|[^[:alnum:]_-])chsh([^[:alnum:]_-]|$)|hyprctl[[:space:]]+reload' \
  "$repo/setup.yml" "$repo/tasks" "$repo/vars/Omarchy.yml"; then
  fail 'prohibited package/update/activation command in repository task code'
fi

mapfile -t packages < <(
  awk '
    /^omarchy_packages:/ { in_packages=1; next }
    in_packages && /^  - / { sub(/^  - /, ""); print; next }
    in_packages { exit }
  ' "$repo/vars/Omarchy.yml"
)
[[ ${#packages[@]} -eq 2 ]] || fail 'Omarchy package allowlist must contain exactly two entries'
[[ ${packages[0]} == omarchy-zsh && ${packages[1]} == yazi ]] ||
  fail 'Omarchy package allowlist must be exactly: omarchy-zsh yazi'

mapfile -t managed_paths < <(awk '/^    dest: / { sub(/^    dest: /, ""); print }' "$repo/vars/Omarchy.yml")
expected_paths=(
  .config/dotfiles/zsh/personal.zsh
  .config/dotfiles/starship.toml
  .config/yazi
)
[[ ${managed_paths[*]} == "${expected_paths[*]}" ]] ||
  fail 'Omarchy managed-path allowlist must contain only personal Zsh, unique Starship, and Yazi targets'

for forbidden in \
  'hypr/hyprland.lua' 'hypr/bindings.lua' 'omarchy/shell.json' \
  'foot/foot.ini' 'ghostty/config' '.config/nvim' '.config/tmux' \
  '.tmux.conf' '.config/atuin' '.config/sheldon' 'fonts/'; do
  if grep -FRq -- "$forbidden" "$repo/vars/Omarchy.yml" "$repo/tasks/omarchy.yml" "$repo/omarchy"; then
    fail "forbidden Omarchy-managed path: $forbidden"
  fi
done

if awk '/^[[:space:]]+dest:/ && $0 !~ /{{ home }}\// { print; bad=1 } END { exit bad ? 0 : 1 }' \
  "$repo/tasks/omarchy.yml" | grep -q .; then
  fail 'every Omarchy task destination must begin with {{ home }}/'
fi

require_text setup.yml 'is_omarchy: "{{ (ansible_distribution | lower) == '\''omarchy'\'' }}"'
require_text setup.yml "is_legacy_platform: \"{{ ansible_os_family in ['Darwin', 'Debian'] and not is_omarchy }}\""
require_text setup.yml "vars/{{ 'Omarchy' if is_omarchy else ansible_os_family }}.yml"
require_text setup.yml 'when: is_legacy_platform'
require_text setup.yml "when: ansible_os_family == 'Debian' and not is_omarchy"
require_text setup.yml 'tags: [omarchy, never]'
require_text tasks/desktop.yml "ansible_os_family == 'Debian'"
require_text tasks/desktop.yml 'not is_omarchy'

require_text tasks/omarchy.yml '"pkg", "present"'
grep -Eq "['\"]pkg['\"], ['\"]add['\"]" "$repo/tasks/omarchy.yml" ||
  fail 'tasks/omarchy.yml missing public pkg add argv'
require_text tasks/omarchy.yml 'become: "{{ omarchy_become | default(true) }}"'
require_text tasks/omarchy.yml 'tags: [omarchy_packages, never]'
require_text tasks/omarchy.yml 'tags: [omarchy_config, never]'

zshrc="$repo/omarchy/zsh/.zshrc"
# These searches intentionally match literal Zsh variable references.
# shellcheck disable=SC2016
zoptions_line=$(grep -nF 'source "$omarchy_zsh_root/shell/zoptions"' "$zshrc" | cut -d: -f1)
# shellcheck disable=SC2016
all_line=$(grep -nF 'source "$omarchy_zsh_root/shell/all"' "$zshrc" | cut -d: -f1)
# shellcheck disable=SC2016
personal_line=$(grep -nF 'source "$HOME/.config/dotfiles/zsh/personal.zsh"' "$zshrc" | cut -d: -f1)
[[ -n $zoptions_line && -n $all_line && -n $personal_line ]] || fail 'incomplete Omarchy Zsh loader chain'
(( zoptions_line < all_line && all_line < personal_line )) || fail 'personal Zsh code must load after both official loaders'
# shellcheck disable=SC2016
require_text omarchy/zsh/.zshrc 'export STARSHIP_CONFIG="$HOME/.config/dotfiles/starship.toml"'

if grep -ERiq 'sheldon|atuin|starship init|zoxide init|fzf --zsh|fnm|mise' "$repo/omarchy/zsh/personal.zsh"; then
  fail 'personal Omarchy overlay reinitializes an official/skipped shell tool'
fi

require_text .github/workflows/test-setup-ci.yml 'bash tests/omarchy-boundaries.sh'
require_text .github/workflows/test-setup-ci.yml 'REQUIRE_ANSIBLE=1 bash tests/omarchy-integration.sh'
require_text README.md '## Omarchy (opt-in)'
require_text README.md 'ansible-playbook setup.yml -K --tags omarchy --check --diff'
require_text README.md 'ansible-playbook setup.yml -K --tags omarchy'
require_text README.md 'ansible-playbook setup.yml --tags omarchy_config'
require_text README.md 'omarchy-setup-zsh'
require_text README.md '### Omarchy rollback'

printf 'Omarchy boundary checks passed\n'
