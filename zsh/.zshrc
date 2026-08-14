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

# These were appended by their installers on macOS with an absolute /Users path,
# which is dead weight on PATH everywhere else. $HOME-relative and guarded on
# the directory existing, so each machine only picks up what it actually has.

# Added by Antigravity
[ -d "$HOME/.antigravity/antigravity/bin" ] && export PATH="$HOME/.antigravity/antigravity/bin:$PATH"

# Added by Antigravity IDE
[ -d "$HOME/.antigravity-ide/antigravity-ide/bin" ] && export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"
