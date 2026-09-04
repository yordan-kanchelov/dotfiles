# Official Omarchy environment and shell integration first; personal additions last.
[[ -o interactive ]] || return

omarchy_root=${OMARCHY_PATH:-/usr/share/omarchy}
omarchy_zsh_root=${OMARCHY_ZSH_PATH:-/usr/share/omarchy-zsh}

[[ -r "$omarchy_root/default/bash/env-bootstrap" ]] &&
  source "$omarchy_root/default/bash/env-bootstrap"

export STARSHIP_CONFIG="$HOME/.config/dotfiles/starship.toml"

[[ -r "$omarchy_zsh_root/shell/zoptions" ]] &&
  source "$omarchy_zsh_root/shell/zoptions"
[[ -r "$omarchy_zsh_root/shell/all" ]] &&
  source "$omarchy_zsh_root/shell/all"
[[ -r "$HOME/.config/dotfiles/zsh/personal.zsh" ]] &&
  source "$HOME/.config/dotfiles/zsh/personal.zsh"
