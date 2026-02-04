# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a macOS dotfiles repository that provides automated setup for a modern terminal environment. The setup is TypeScript-based and uses Node.js with experimental TypeScript support (no compilation required).

## Essential Commands

### Setup & Installation
```bash
# Bootstrap Node.js if needed
./bootstrap.sh

# Install dependencies
npm install

# Main setup commands
npm run setup              # Interactive setup (prompts for each action)
npm run setup:force        # Overwrites existing files with backups
npm run setup:append       # Appends to existing configs instead of replacing
npm run setup:no-packages  # Only configs, skip Homebrew packages
npm run ci:setup          # Non-interactive for CI environments
```

### Development & Testing
```bash
# Run tests
npm test                   # Run all tests
npm test -- test/setup.test.ts  # Run specific test file

# Type checking
npm run typecheck

# Testing in CI mode (dry run)
CI=true npm run ci:setup
```

## Architecture & Key Components

### Core Setup System (setup.ts)
- Entry point for all dotfile installations
- Handles symlink creation, file backups, and package installation
- Uses Commander for CLI options and Inquirer for interactive prompts
- Implements smart conflict resolution with backup strategy
- All backups stored in `~/.dotfiles_backup/` with timestamps

### Configuration Structure
```
.config/
├── nvim/          # LazyVim Neovim configuration
├── starship.toml  # Prompt configuration
├── ghostty/       # Terminal emulator config
└── atuin/         # Shell history sync

zsh/
├── .zprofile      # Login shell: env vars, PATH, SSH agent, secrets
├── .zshrc         # Sources .zshrc.core + tool-generated additions
└── .zshrc.core    # Interactive: plugins, prompt, aliases, functions

tmux/
└── .tmux.conf     # Tmux with TPM plugin manager
```

### Package Management
- `brew_packages.txt`: Line-separated list of Homebrew formulae/casks
- Automatically installs missing packages during setup
- Handles both CLI tools and GUI applications (casks)

### Node.js Requirements
- Requires Node.js 22.14.0+ for experimental TypeScript support
- Uses `--experimental-strip-types` flag to run TypeScript directly
- No build step or transpilation needed

## Key Implementation Details

### Symlink Strategy
The setup creates symlinks from home directory to dotfiles repo:
- `~/.zshrc` → `~/dotfiles/zsh/.zshrc`
- `~/.config/nvim` → `~/dotfiles/.config/nvim`
- Preserves repo structure for easy version control

### Backup System
Before any file operation:
1. Checks if target exists
2. Creates timestamped backup in `~/.dotfiles_backup/`
3. Only then proceeds with symlink/copy

### Interactive vs Non-Interactive Modes
- Interactive mode prompts for each file conflict
- Non-interactive mode uses defaults (useful for CI)
- Force mode overwrites with backups but no prompts

### Testing Approach
Tests use Node.js built-in test runner:
- Mocks HOME directory for isolation
- Tests symlink creation, backup functionality
- Verifies CLI argument handling

## Important Notes

- Primary target is macOS, some features may work on Linux
- Fonts are included in `fonts/` directory but require manual installation
- Sensitive data should be stored in `~/.secrets` (sourced by .zprofile at login)
- The setup preserves existing tmux/zsh plugin installations
