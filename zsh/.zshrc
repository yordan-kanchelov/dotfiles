#!/usr/bin/env zsh

# increase function nesting limit
FUNCNEST=1000

# zplug initialization
if [[ ! -d ~/.zplug ]]; then
  echo "Installing zplug..."
  curl -sL https://raw.githubusercontent.com/zplug/installer/master/installer.zsh | zsh
fi

source ~/.zplug/init.zsh
source <(fzf --zsh)

# Load plugins using zplug
zplug "zsh-users/zsh-autosuggestions", defer:2
zplug "zsh-users/zsh-syntax-highlighting", defer:3

# zsh vim mode
zplug "jeffreytse/zsh-vi-mode"

if ! zplug check --verbose; then
  echo "Installing missing plugins..."
  zplug install
fi
zplug load

# Initialize Starship prompt (add this line)
if ! type starship_zle-keymap-select >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

eval "$(atuin init zsh)"
eval "$(fnm env --use-on-cd --shell zsh)"
eval "$(ssh-agent -s)"
eval "$(zoxide init zsh)"

if grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; then
  alias explorer="explorer.exe"
  alias open="explorer.exe"
  alias kubectl='kubectl.exe'
  alias minikube='minikube.exe'
fi

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
alias cat="bat"
alias ':q'='exit'
alias l='eza -l -b --all --header --git --icons --group-directories-first'
alias ls='eza -l -b --all --header --git --icons --group-directories-first'
alias or="ollama run gemma3:4b"

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

# Alias for the function
alias cleanc='clean_dev_caches'

clean_project() {
    # Enable extended globbing for ** pattern
    setopt local_options extended_glob null_glob

    # Array of patterns to remove
    local patterns=(
        dist
        .nx/cache
        **/node_modules(N)
        **/pnpm-lock.yaml(N)
        **/package-lock.json(N)
    )

    # Counter for removed items
    local removed_count=0

    echo "🧹 Cleaning project files..."

    # Process each pattern
    for pattern in $patterns; do
        # Find matching files/directories
        local matches=($~pattern)

        # If matches found, remove them
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

    # Summary
    if [[ $removed_count -eq 0 ]]; then
        echo "  ℹ️  No files found to remove"
    else
        echo "  ✅ Removed $removed_count items"
    fi

    # clean_dev_caches
}

# Optional: Create an alias for easier access
alias cleanp='clean_project'

fvim() {
  local selected_file

  # Run fzf.
  # If you press Escape (or fzf is otherwise aborted),
  # the command substitution $(...) will result in an empty string.
  # The --bind "esc:abort" makes the Escape behavior explicit,
  # though fzf usually aborts on Escape by default.
  selected_file=$(fzf --preview="bat --color=always {}" --bind "esc:abort")

  # Check if fzf returned a non-empty string (meaning a file was selected)
  if [ -n "$selected_file" ]; then
    # Only open nvim if a file was actually selected
    nvim "$selected_file"
  fi
  # If 'selected_file' is empty (because you pressed Esc in fzf),
  # the 'if' condition is false, and this function will simply end
  # without calling nvim.
}

# Additional sources
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"

export OPENAI_API_KEY=""
export EDITOR=nvim

# function to run ollama with a prompt and a file
ollama_prompt_file() {
  local initial_text="$1"
  local file_to_cat="$2"
  local ollama_model="gemma3:4b" # ollama model selection

  if [ -z "$initial_text" ] || [ -z "$file_to_cat" ]; then
    echo "Usage: ollama_prompt_file <initial_text> <file_to_cat> [ollama_model]"
    echo "Example: ollama_prompt_file 'Summarize this:' notes.txt mistral"
    return 1
  fi

  if [ ! -f "$file_to_cat" ]; then
    echo "Error: File not found at '$file_to_cat'"
    return 1
  fi

  # If a third argument is provided, use it as the model name
  if [ ! -z "$3" ]; then
    ollama_model="$3"
  fi

  # The core command: combines echo and cat, then pipes to ollama
  { echo "$initial_text"; cat "$file_to_cat"; } | ollama run "$ollama_model"
}

alias orf="ollama_prompt_file"

