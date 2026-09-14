# shellcheck shell=bash
# Loaded last, after the official loader and existing user customizations.
[[ $- == *i* ]] || return 0
# shellcheck source=omarchy/shell/aliases.sh
source "$HOME/.config/dotfiles/shell/aliases.sh"
alias reload='exec bash'
set -o vi
if [[ -r ${OMARCHY_PATH:-/usr/share/omarchy}/default/bash/inputrc ]]; then
  bind -m vi-insert -f "${OMARCHY_PATH:-/usr/share/omarchy}/default/bash/inputrc"
fi
