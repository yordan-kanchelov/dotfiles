#!/usr/bin/env zsh

typeset -U path PATH

if [ -f "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f "/usr/local/bin/brew" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

if [[ "$OSTYPE" == darwin* ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
fi

export PATH="$PNPM_HOME:$HOME/.local/bin:$PATH"

export EDITOR="nvim"

if command -v fnm &> /dev/null; then
  eval "$(fnm env --shell zsh)"
fi

if [ -f ~/.secrets ]; then
  source ~/.secrets
fi

source ~/.orbstack/shell/init.zsh 2>/dev/null || :
