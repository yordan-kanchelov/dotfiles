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
# PATH MODIFICATIONS
# ============================================
export PATH="$HOME/.local/bin:$PATH"

# ============================================
# ENVIRONMENT VARIABLES
# ============================================
export EDITOR=code

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
# SSH AGENT
# ============================================
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
# SECRETS
# ============================================
if [ -f ~/.secrets ]; then
  source ~/.secrets
fi
