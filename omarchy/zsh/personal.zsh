# Personal additions loaded after the official Omarchy Zsh integration.
alias ':q'='exit'
alias reload='exec zsh'

if (( $+commands[eza] )); then
  alias l='eza -l -b --all --header --git --icons --group-directories-first'
  alias ls='eza -l -b --all --header --git --icons --group-directories-first'
fi
(( $+commands[nvim] )) && alias vim='nvim'
(( $+commands[lazygit] )) && alias lg='lazygit'

if (( $+commands[yazi] )); then
  y() {
    local tmp cwd
    tmp=$(mktemp -t yazi-cwd.XXXXXX) || return
    command yazi "$@" --cwd-file="$tmp"
    cwd=$(<"$tmp")
    rm -f -- "$tmp"
    [[ -n $cwd && $cwd != "$PWD" && -d $cwd ]] && builtin cd -- "$cwd"
  }
fi
