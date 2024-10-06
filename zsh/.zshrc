# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.oh-my-zsh"
source $ZSH/oh-my-zsh.sh

# Initialize zinit
source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"

# Install Powerlevel10k theme using zplug
zinit light romkatv/powerlevel10k

# Install plugins
zinit light zsh-users/zsh-autosuggestions
zinit light zsh-users/zsh-syntax-highlighting
zinit light zsh-users/zsh-completions

plugins=(git fnm colorize)

# Initialize atuin
. "$HOME/.atuin/bin/env"
eval "$(atuin init zsh)"

# To customize prompt, run p10k configure or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# Aliases
alias explorer="explorer.exe"
alias open="explorer.exe"
alias ghcs='gh copilot suggest'
alias kubectl='kubectl.exe'
alias minikube='minikube.exe'

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

NEOVIM_PATH="/opt/nvim-linux64/bin"
if [ -d "$NEOVIM_PATH" ]; then
  export PATH="$NEOVIM_PATH:$PATH"
fi
# fnm
FNM_PATH="/home/yordan/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="/home/yordan/.local/share/fnm:$PATH"
  eval "`fnm env`"
fi

### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

autoload -Uz _zinit

(( ${+_comps} )) && _comps[zinit]=_zinit
### End of Zinit's installer chunk
