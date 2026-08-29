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

# if-blocks, not `[ -d ] &&`: a bare && chain as the file's last statement makes
# the whole .zshrc return 1 when the dir is absent, and starship paints the
# first prompt of every shell as an error.
if [ -d "$HOME/.antigravity/antigravity/bin" ]; then # Added by Antigravity
  export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
fi

if [ -d "$HOME/.antigravity-ide/antigravity-ide/bin" ]; then # Added by Antigravity IDE
  export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"
fi
