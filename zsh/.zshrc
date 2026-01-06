#!/usr/bin/env zsh

# Increase function nesting limit
FUNCNEST=1000

# ============================================
# ZPLUG INITIALIZATION
# ============================================
if [[ ! -d ~/.zplug ]]; then
  echo "Installing zplug..."
  curl -sL https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
fi

source ~/.zplug/init.zsh

# Load plugins using zplug with defer
zplug "zsh-users/zsh-autosuggestions", defer:2
zplug "zsh-users/zsh-syntax-highlighting", defer:3
zplug "jeffreytse/zsh-vi-mode"

# Silent install check (only checks when needed)
if ! zplug check; then
  echo "Installing missing plugins..."
  zplug install
fi
zplug load

# ============================================
# COMPLETIONS - OPTIMIZE THIS SECTION
# ============================================
# Docker Desktop adds completions
fpath=(/Users/yordan.kanchelov/.docker/completions $fpath)

# Only run compinit once, with caching
autoload -Uz compinit
if [[ -n ${HOME}/.zcompdump(#qNmh+24) ]]; then
  compinit
else
  compinit -C  # Skip security check if dump is < 24h old
fi

# ============================================
# TOOL INITIALIZATIONS (kept as-is, but optimized)
# ============================================

source <(fzf --zsh)

# Initialize tools
eval "$(starship init zsh)"
eval "$(atuin init zsh)"
eval "$(fnm env --shell zsh)"
eval "$(zoxide init zsh)"


if [ -z "$SSH_AUTH_SOCK" ]; then
  SSH_ENV="$HOME/.ssh/agent-env"

  if [ -f "$SSH_ENV" ]; then
    source "$SSH_ENV" > /dev/null
    # Check if agent is still running
    if ! kill -0 $SSH_AGENT_PID 2>/dev/null; then
      eval "$(ssh-agent -s)" > /dev/null
      echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > "$SSH_ENV"
      echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> "$SSH_ENV"
    fi
  else
    eval "$(ssh-agent -s)" > /dev/null
    echo "export SSH_AUTH_SOCK=$SSH_AUTH_SOCK" > "$SSH_ENV"
    echo "export SSH_AGENT_PID=$SSH_AGENT_PID" >> "$SSH_ENV"
  fi
fi

# ============================================
# ALIASES
# ============================================
alias ghcs='gh copilot suggest'
alias ta="tmux attach-session -t"
alias tn="tmux new -s"
alias tls="tmux list-sessions"
alias tk="tmux kill-session -t"
alias tkill="tmux kill-server"
alias tlist="tmux list-sessions"
alias tren="tmux rename-session -t"
alias tnw="tmux new-window"
alias th="tmux split-window -h"
alias tv="tmux split-window -v"
alias tkp="tmux kill-pane"
alias vim="nvim"
alias ':q'='exit'
alias l='eza -l -b --all --header --git --icons --group-directories-first'
alias ls='eza -l -b --all --header --git --icons --group-directories-first'
alias cleanc='clean_dev_caches'
alias cleanp='clean_project'

# ============================================
# FUNCTIONS
# ============================================
clean_dev_caches() {
  echo "🧹 Cleaning npm cache..."
  npm cache clean --force
  echo "🧹 Pruning pnpm store..."
  pnpm store prune
  echo "✅ Caches cleaned and pruned!"
  echo "🧹 Clean Docker cache..."
  docker system prune -f --volumes
  echo "✅ Docker cache cleaned!"
}

clean_project() {
    setopt local_options extended_glob null_glob
    local patterns=(
        .nx/cache
        **/dist(N)
        **/node_modules(N)
        **/pnpm-lock.yaml(N)
        **/package-lock.json(N)
        **/release(N)
        **/dist-electron(N)
    )
    local removed_count=0
    echo "🧹 Cleaning project files..."
    for pattern in $patterns; do
        local matches=($~pattern)
        if [[ ${#matches[@]} -gt 0 ]]; then
            for item in $matches; do
                if [[ -e "$item" ]]; then
                    echo "  ✓ Removing: $item"
                    rm -rf "$item" 2>/dev/null
                    ((removed_count++))
                fi
            done
        fi
    done
    if [[ $removed_count -eq 0 ]]; then
        echo "  ℹ️  No files found to remove"
    else
        echo "  ✅ Removed $removed_count items"
    fi
}

fvim() {
  local selected_file
  selected_file=$(fzf --preview="bat --color=always {}" --bind "esc:abort")
  if [ -n "$selected_file" ]; then
    nvim "$selected_file"
  fi
}

cat() {
  if [ $# -eq 0 ]; then
        command bat
        return
    fi
    local file="$1"
    if [ ! -f "$file" ]; then
        command bat "$@"
        return
    fi
    local mime=$(file --mime-type -b "$file" 2>/dev/null)
    case "$mime" in
        image/*)
            local term_width=$(tput cols)
            viu -w $((term_width - 2)) "$@"
            ;;
        application/pdf)
            if command -v termpdf &> /dev/null; then
                termpdf "$file"
            elif command -v pdftotext &> /dev/null; then
                pdftotext -layout "$file" - | command bat -l txt
            else
                echo "Install pdftotext or termpdf for better PDF viewing"
                command bat "$@"
            fi
            ;;
        video/*)
            if command -v ffmpeg &> /dev/null; then
                ffmpeg -i "$file" -ss 00:00:01.000 -vframes 1 -f image2pipe -vcodec png - 2>/dev/null | viu -
            else
                echo "Install ffmpeg to preview videos"
            fi
            ;;
        *)
            case "${file:l}" in
                *.md|*.markdown)
                    if command -v glow &> /dev/null; then
                        glow "$file"
                    else
                        command bat "$@"
                    fi
                    ;;
                *)
                    command bat "$@"
                    ;;
            esac
            ;;
    esac
}

# ============================================
# ENVIRONMENT VARIABLES & PATH
# ============================================
export EDITOR=code

# Source secrets from local file (not in version control)
if [ -f ~/.secrets ]; then
  source ~/.secrets
fi


export PATH="$HOME/.local/bin:$PATH"
