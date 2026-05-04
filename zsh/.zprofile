#!/usr/bin/env zsh

# ============================================
# ZSH PROFILE - Login Shell Configuration
# Runs once at login, before .zshrc
# Contains: Environment variables, PATH, SSH agent
# ============================================

# ============================================
# HOMEBREW
# ============================================
if [ -f "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f "/usr/local/bin/brew" ]; then
  eval "$(/usr/local/bin/brew shellenv)"
fi

# ============================================
# PNPM
# ============================================
export PNPM_HOME="$HOME/Library/pnpm"

# ============================================
# PATH MODIFICATIONS
# ============================================
export PATH="$PNPM_HOME:$HOME/.local/bin:$PATH"

# ============================================
# ENVIRONMENT VARIABLES
# ============================================
export EDITOR="code -w"

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
