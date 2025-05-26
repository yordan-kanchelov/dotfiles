# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a dotfiles repository for macOS terminal productivity tools. It provides an automated setup script that installs and configures various CLI tools and terminal emulators.

## Common Commands

### Initial Setup
- **Bootstrap Node.js**: `./bootstrap.sh` - Ensures Node.js is installed via fnm
- **Install dependencies**: `npm install`
- **Run setup**: `npm run setup` - Interactive installation

### Testing & Development
- **Run tests**: `npm test`
- **Run tests (watch)**: `npm run test:watch`
- **Type check**: `npm run typecheck`

### Setup Options
- `npm run setup:interactive` - Run with prompts (default)
- `npm run setup:force` - Overwrite existing files without prompting
- `npm run setup:append` - Append to existing config files
- `npm run setup:no-packages` - Skip Homebrew package installation
- `npm run ci:setup` - Non-interactive setup for CI environments

## Architecture & Key Components

### Bootstrap & Setup Process
1. **`bootstrap.sh`** - Ensures Node.js is available via fnm
   - Installs fnm if not present
   - Installs Node.js LTS version
   - Creates .nvmrc file for consistency
   - Runs npm install in non-CI environments

2. **`setup.ts`** - Main setup script (TypeScript):
   - Written in TypeScript with full type safety
   - Runs directly with Node.js 22+ using `--experimental-strip-types`
   - Installs Homebrew if not present
   - Installs packages from `brew_packages.txt`
   - Creates symlinks for all configuration files
   - Sets up tmux plugin manager (TPM)
   - Handles backups of existing files
   - Provides interactive prompts with fallback options

### Configuration Structure
- **zsh/**: ZSH configuration with zplug plugin manager
  - Configures: autosuggestions, syntax highlighting, vi-mode
  - Integrates: starship prompt, atuin, fnm, zoxide
- **tmux/**: Tmux configuration with TPM
- **.config/**: Modern tool configurations
  - starship.toml - Cross-shell prompt
  - ghostty - Terminal emulator config
  - atuin - Shell history sync
- **fonts/**: Nerd Font collections (FiraCode, RobotoMono)

### Installed Tools (brew_packages.txt)
Key productivity tools include:
- Terminal enhancements: bat, eza, ripgrep, fzf, tmux
- Dev tools: neovim, lazygit, gh, go, python
- Modern CLI utilities: atuin, zoxide, yazi, starship
- API tools: grpcurl, ghz, bruno

### Testing & CI/CD
- **Test Suite** (`test/setup.test.ts`): Node.js native test runner
  - Tests symlink creation
  - Tests CLI options handling
  - Tests CI environment detection
  - Tests error handling
- **GitHub Actions** (`.github/workflows/test-setup-ci.yml`):
  - macOS: Full setup test with package installation
  - Ubuntu: Limited test with fnm installation
  - Linting: TypeScript and ShellCheck

### Key Design Decisions
1. Symlinks are preferred over copying files for easy updates
2. Automatic backups before overwriting any existing files
3. Special handling for shell RC files (can append instead of replace)
4. CI-aware (auto-detects and adjusts behavior)
5. macOS-focused but handles other platforms gracefully

## Development Workflow

### Running a single test
```bash
# Run specific test file
node --experimental-strip-types --test test/setup.test.ts

# Run tests matching a pattern
node --test --test-name-pattern="Symlink Creation"
```

### Debugging setup issues
1. Check backup directory: `~/.dotfiles_backup/` for any backed up files
2. Run with verbose output: `DEBUG=* npm run setup`
3. Test in CI mode locally: `CI=true npm run ci:setup`

### Adding new dotfiles
1. Add the file to the appropriate directory (e.g., `.config/`, `zsh/`, etc.)
2. The setup script automatically discovers and symlinks:
   - Files in `.config/` directory
   - `.zshrc` from `zsh/` directory
   - `.tmux.conf` from `tmux/` directory
3. Update tests if adding new functionality

### Package management
- Add new Homebrew packages to `brew_packages.txt` (one per line)
- Comments in `brew_packages.txt` start with `#`
- The setup script skips installation on non-macOS systems
