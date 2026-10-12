#!/usr/bin/env zsh

# ============================================
# ZSH PROFILE - Login Shell Configuration
# Runs once at login, before .zshrc
# Contains: Environment variables, PATH, SSH agent
# ============================================

# Shared tool PATH also covers interactive non-login shells.
if [[ -f ~/.zshrc.tools ]]; then
  source ~/.zshrc.tools
fi

# ============================================
# ENVIRONMENT VARIABLES
# ============================================
export EDITOR="nvim"

# Add your custom environment variables below:
# export JAVA_HOME=/path/to/java
# export ANDROID_HOME=$HOME/Library/Android/sdk


# ============================================
# SECRETS
# ============================================
if [ -f ~/.secrets ]; then
  source ~/.secrets
fi

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
