#!/usr/bin/env zsh

if [ -f ~/.zshrc.core ]; then
  source ~/.zshrc.core
fi

if [ -d "$HOME/.antigravity/antigravity/bin" ]; then
  export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
fi

if [ -d "$HOME/.antigravity-ide/antigravity-ide/bin" ]; then
  export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"
fi
