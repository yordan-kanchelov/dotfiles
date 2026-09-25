# shellcheck shell=bash
# Personal layer on top of Omarchy's Bash. Sourced from a managed block at the
# end of ~/.bashrc, so Omarchy's rc (starship, fzf, zoxide, mise, aliases) has
# already run and anything here wins. Omarchy owns `ls`, `c` and the prompt.
[[ $- == *i* ]] || return 0

# ============================================
# ENVIRONMENT
# ============================================
export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
case ":$PATH:" in *":$PNPM_HOME:"*) ;; *) PATH="$PNPM_HOME:$PATH" ;; esac

# shellcheck source=/dev/null
[[ -r ~/.secrets ]] && source ~/.secrets

# ============================================
# VI MODE
# ============================================
# Omarchy's rc binds its inputrc in emacs mode; re-bind it into vi-insert so
# TAB completion and prefix Up/Down history keep working after the switch.
set -o vi
if [[ -r ${OMARCHY_PATH:-/usr/share/omarchy}/default/bash/inputrc ]]; then
  bind -m vi-insert -f "${OMARCHY_PATH:-/usr/share/omarchy}/default/bash/inputrc"
fi

# ============================================
# ALIASES
# ============================================
alias reload='exec bash'
alias ':q'='exit'
alias tkp='exit'
alias ta='tmux attach-session -t'
alias tn='tmux new -s'
alias tls='tmux list-sessions'
alias tk='tmux kill-session -t'
alias tkill='tmux kill-server'
alias tren='tmux rename-session -t'
alias tnw='tmux new-window'
alias th='tmux split-window -h'
alias tv='tmux split-window -v'
alias l='eza -l -b --all --header --git --icons --group-directories-first'
alias vim='nvim'
alias lg='lazygit'
alias sw='sync-worktrees'
alias cleanc='clean_dev_caches'
alias cleanp='clean_project'

# ============================================
# FUNCTIONS
# ============================================
# Also drop tmux scrollback, so an old error can't be scrolled back into view.
clear() {
  command clear
  [[ -n $TMUX ]] && tmux clear-history
  return 0
}

# Pin a per-pane session id so tmux-resurrect restores each pane into its own
# conversation. Bare `claude` -> mint a new id. Resurrect re-types
# `claude --session-id <uuid>`; if that transcript already exists, resume it
# (claude itself only resumes via --resume, not --session-id). Anything else passes
# through (-c, -r, -p, subcommands like `claude mcp`).
claude() {
  if [[ $1 == --session-id && -n $2 ]]; then
    local id=$2
    if compgen -G "$HOME/.claude/projects/*/$id.jsonl" >/dev/null; then
      shift 2
      command claude --resume "$id" "$@"
      return
    fi
  elif (($# == 0)); then
    set -- --session-id "$(uuidgen | tr '[:upper:]' '[:lower:]')"
  fi
  command claude "$@"
}

y() {
  local tmp cwd exit_code=0
  tmp=$(mktemp -t yazi-cwd.XXXXXX) || return
  command yazi --cwd-file="$tmp" "$@" || exit_code=$?
  IFS= read -r -d '' cwd <"$tmp" || :
  command rm -f -- "$tmp"
  [[ $exit_code -eq 0 ]] || return "$exit_code"
  if [[ -n $cwd && $cwd != "$PWD" && -d $cwd ]]; then
    builtin cd -- "$cwd" || return
  fi
}

fvim() {
  local selected_file
  selected_file=$(fzf --preview='bat --color=always -- {}' --bind 'esc:abort') || return
  [[ -n $selected_file ]] && nvim -- "$selected_file"
}

# bat for text, glow for markdown, viu for images. Plain cat when piped or
# redirected, and the function isn't exported, so scripts never see it.
cat() {
  if [[ ! -t 1 ]] || ! command -v bat >/dev/null; then
    command cat "$@"
    return
  fi
  if (($# == 0)) || [[ ! -f $1 ]]; then
    command bat "$@"
    return
  fi
  local file=$1 mime
  mime=$(file --mime-type -b "$file" 2>/dev/null)
  case $mime in
    image/*)
      if command -v viu >/dev/null; then
        viu -w $(($(tput cols) - 2)) "$@"
      else
        echo "Install viu to preview images"
      fi
      ;;
    application/pdf)
      if command -v pdftotext >/dev/null; then
        pdftotext -layout "$file" - | command bat -l txt
      else
        echo "Install pdftotext (poppler) for better PDF viewing"
        command bat "$@"
      fi
      ;;
    video/*)
      if command -v ffmpeg >/dev/null && command -v viu >/dev/null; then
        ffmpeg -i "$file" -ss 00:00:01.000 -vframes 1 -f image2pipe -vcodec png - 2>/dev/null | viu -
      else
        echo "Install ffmpeg and viu to preview videos"
      fi
      ;;
    *)
      case ${file,,} in
        *.md | *.markdown)
          if command -v glow >/dev/null; then glow "$file"; else command bat "$@"; fi
          ;;
        *) command bat "$@" ;;
      esac
      ;;
  esac
}

clean_dev_caches() {
  echo "Cleaning npm cache..."
  npm cache clean --force
  echo "Pruning pnpm store..."
  pnpm store prune
  echo "Caches cleaned and pruned!"
  local reply
  read -rp "Run 'docker system prune -f --volumes'? This deletes stopped containers AND their volumes [y/N] " reply
  if [[ $reply =~ ^[Yy]$ ]]; then
    docker system prune -f --volumes
    echo "Docker cache cleaned!"
  else
    echo "Skipped Docker prune."
  fi
}

# Subshell body: job control is off in subshells, so the parallel rm jobs don't
# print [1] PID / Done lines (zsh used setopt no_monitor no_notify).
clean_project() (
  echo "Cleaning project files..."
  count=0
  remove_all() {
    local item
    while IFS= read -r item; do
      echo "  Removing: $item"
      rm -rf -- "$item" &
      ((++count % 4 == 0)) && wait
    done
    wait
  }
  remove_all < <(find . -type d \( -name node_modules -o -path '*/.nx/cache' \) -prune -print 2>/dev/null)
  remove_all < <(
    find . \
      -type d \( -name dist -o -name release -o -name dist-electron \) -prune -print \
      -o -type f \( -name pnpm-lock.yaml -o -name package-lock.json \) -print \
      2>/dev/null
  )
  if ((count == 0)); then
    echo "  No files found to remove"
  else
    echo "  Removed $count items"
  fi
)

# ============================================
# ATUIN (last: it must bind Ctrl-R and Up after fzf and the vi-mode inputrc)
# ============================================
if command -v atuin >/dev/null && [[ -r /usr/share/bash-preexec/bash-preexec.sh ]]; then
  # shellcheck source=/dev/null
  source /usr/share/bash-preexec/bash-preexec.sh
  eval "$(atuin init bash)"
fi
