#!/usr/bin/env zsh

# ============================================
# ZSH PROFILE - Login Shell Configuration
# Runs once at login, before .zshrc
# Contains: Environment variables, PATH, SSH agent
# ============================================

# Deduplicate PATH entries (installers love re-appending)
typeset -U path PATH

# ============================================
# HOMEBREW
# ============================================
# Apple Silicon, Intel Mac, then Linuxbrew.
if [ -f "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f "/usr/local/bin/brew" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
elif [ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ============================================
# PNPM
# ============================================
# pnpm's own default differs per platform; hardcoding the macOS one put a
# nonexistent ~/Library path on Linux's PATH.
if [[ "$OSTYPE" == darwin* ]]; then
  export PNPM_HOME="$HOME/Library/pnpm"
else
  export PNPM_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/pnpm"
fi

# ============================================
# PATH MODIFICATIONS
# ============================================
export PATH="$PNPM_HOME:$HOME/.local/bin:$PATH"

# ============================================
# ENVIRONMENT VARIABLES
# ============================================
export EDITOR="nvim"

# Add your custom environment variables below:
# export JAVA_HOME=/path/to/java
# export ANDROID_HOME=$HOME/Library/Android/sdk

# ============================================
# NODE VERSION MANAGER (fnm)
# ============================================
if command -v fnm &> /dev/null; then
  eval "$(fnm env --shell zsh)"
fi

# ============================================
# SECRETS
# ============================================
if [ -f ~/.secrets ]; then
  source ~/.secrets
fi

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
