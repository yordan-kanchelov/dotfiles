# shellcheck shell=bash
# Selected portable definitions, never framework or runtime initialization.
alias ':q'='exit'
alias tkp='exit'
if command -v tmux >/dev/null 2>&1; then
  alias ta='tmux attach-session -t'
  alias tn='tmux new -s'
  alias tls='tmux list-sessions'
  # Explicit commands only: these destroy a session / all sessions respectively.
  alias tk='tmux kill-session -t'
  alias tkill='tmux kill-server'
  alias tren='tmux rename-session -t'
  alias tnw='tmux new-window'
  alias th='tmux split-window -h'
  alias tv='tmux split-window -v'
fi
if command -v eza >/dev/null 2>&1; then
  alias l='eza -l -b --all --header --git --icons --group-directories-first'
  alias ls='eza -l -b --all --header --git --icons --group-directories-first'
fi
if command -v nvim >/dev/null 2>&1; then alias vim='nvim'; fi
if command -v lazygit >/dev/null 2>&1; then alias lg='lazygit'; fi
if command -v sync-worktrees >/dev/null 2>&1; then alias sw='sync-worktrees'; fi

if command -v yazi >/dev/null 2>&1; then
  y() {
    local tmp cwd exit_code=0
    tmp=$(mktemp -t yazi-cwd.XXXXXX) || return
    command yazi --cwd-file="$tmp" "$@" || exit_code=$?
    IFS= read -r -d '' cwd < "$tmp" || :
    command rm -f -- "$tmp" || return
    [ "$exit_code" -eq 0 ] || return "$exit_code"
    if [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
      builtin cd -- "$cwd" || return
    fi
    return 0
  }
fi

if command -v fzf >/dev/null 2>&1 && command -v bat >/dev/null 2>&1 && command -v nvim >/dev/null 2>&1; then
  fvim() {
    local selected_file
    selected_file=$(command fzf --preview='bat --color=always -- {}' --bind 'esc:abort') || return
    [ -n "$selected_file" ] || return 0
    command nvim -- "$selected_file"
  }
fi
