#!/usr/bin/env zsh

# ============================================
# ZSH CONFIGURATION
# This file sources core config and contains tool-generated additions
# Environment setup is in .zprofile (runs at login)
# Personal configurations are in .zshrc.core
# ============================================

# Source personal/core configuration
if [ -f ~/.zshrc.core ]; then
  source ~/.zshrc.core
fi

# ============================================
# TOOL-GENERATED ADDITIONS
# Tools can safely add their configurations below
# ============================================

# Added by Antigravity
export PATH="/Users/yordan.kanchelov/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity IDE
export PATH="/Users/yordan.kanchelov/.antigravity-ide/antigravity-ide/bin:$PATH"
