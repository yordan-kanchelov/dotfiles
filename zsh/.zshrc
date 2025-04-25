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
eval "$(starship init zsh)"

eval "$(atuin init zsh)"
eval "$(fnm env --use-on-cd --shell zsh)"
eval "$(ssh-agent -s)"

# pnpm setup
export PNPM_HOME="/Users/yordan.kanchelov/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac

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
alias tmn="tmux new -s"
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
alias l='ls -lAh'
alias fvim='nvim $(fzf --preview="bat --color=always {}")'

# --- Enable colored ls output (platform independent) ---
case "$OSTYPE" in
  darwin*)
    # macOS settings
    export CLICOLOR=1
    export LSCOLORS="GxFxCxDxBxegedabagacad"
    alias ls='ls -G'
    ;;
  linux*)
    # Linux settings
    alias ls='ls --color=auto'
    ;;
  *)
    # Fallback (if needed)
    alias ls='ls'
    ;;
    esac

# Additional sources
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
[ -s "$HOME/.config/envman/load.sh" ] && source "$HOME/.config/envman/load.sh"
