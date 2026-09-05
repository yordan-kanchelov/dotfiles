# Omarchy login environment without Homebrew or a node-version manager.
omarchy_root=${OMARCHY_PATH:-/usr/share/omarchy}
[[ -r "$omarchy_root/default/bash/env-bootstrap" ]] &&
  source "$omarchy_root/default/bash/env-bootstrap"

typeset -U path PATH
export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
export PATH="$PNPM_HOME:$HOME/.local/bin:$PATH"
export EDITOR="nvim"

[[ -r "$HOME/.secrets" ]] && source "$HOME/.secrets"
