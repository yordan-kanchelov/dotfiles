# Dotfiles

Modern macOS terminal setup with automated installation and configuration for productivity-focused developers.

## Features

- 🚀 **One-command setup** - Automated installation with intelligent prompts
- 🛡️ **Safe installation** - Automatic backups before overwriting existing configs
- 📦 **Modern CLI tools** - Curated collection of productivity-enhancing utilities
- 🎨 **Beautiful terminal** - Pre-configured with Nerd Fonts and modern themes
- ⚡ **Performance focused** - Fast shell startup with lazy-loaded plugins
- 🔧 **TypeScript-powered** - Type-safe setup script with comprehensive error handling

## Quick Start

```bash
# Clone the repository
git clone https://github.com/yourusername/dotfiles.git ~/dotfiles
cd ~/dotfiles

# Run the bootstrap script (installs Node.js if needed)
./bootstrap.sh

# Run the interactive setup
npm install
npm run setup
```

## What's Included

### Terminal & Shell
- **ZSH** with zplug plugin manager
  - Syntax highlighting
  - Auto-suggestions
  - Vi-mode with visual feedback
  - Directory jumping with zoxide
  - Command history sync with atuin
- **Starship** prompt - Fast, customizable, cross-shell prompt
- **Tmux** with sensible defaults and plugin manager

### Development Tools
- **Neovim** - Modern vim fork
- **Lazygit** - Terminal UI for git
- **GitHub CLI** (`gh`) - GitHub from the command line
- **fnm** - Fast Node.js version manager
- Language support: Go, Python, Rust

### Modern CLI Utilities
- **bat** - `cat` with syntax highlighting
- **eza** - Modern `ls` replacement
- **ripgrep** (`rg`) - Fast file search
- **fzf** - Fuzzy finder for everything
- **yazi** - Terminal file manager
- **atuin** - Sync shell history across machines
- **zoxide** - Smarter `cd` command
- **bruno** - API client

### Fonts
- FiraCode Nerd Font
- RobotoMono Nerd Font

## Installation Options

### Interactive Setup (Default)
```bash
npm run setup
```
Prompts for each action with options to overwrite, skip, or backup existing files.

### Force Installation
```bash
npm run setup:force
```
Overwrites existing files without prompting (creates backups first).

### Append to Existing Configs
```bash
npm run setup:append
```
Appends configuration to existing shell RC files instead of replacing them.

### Skip Package Installation
```bash
npm run setup:no-packages
```
Only sets up configuration files, skips Homebrew package installation.

### CI/Automated Setup
```bash
npm run ci:setup
```
Non-interactive installation for CI environments.

## Configuration

### Adding New Packages
Edit `brew_packages.txt` to add new Homebrew packages (one per line).

### Directory Structure
```
.
├── bootstrap.sh          # Node.js setup script
├── setup.ts             # Main installation script
├── brew_packages.txt    # Homebrew packages list
├── .config/            # Modern tool configs
│   ├── starship.toml   # Starship prompt
│   ├── ghostty/        # Ghostty terminal
│   └── atuin/          # Shell history
├── zsh/                # ZSH configuration
│   └── .zshrc
├── tmux/               # Tmux configuration
│   └── .tmux.conf
└── fonts/              # Nerd Font collections
```

### Backup Location
Existing files are backed up to `~/.dotfiles_backup/` with timestamps.

## Requirements

- macOS (primary target, some features work on Linux)
- Command Line Tools for Xcode
- Internet connection for package downloads

## Development

### Running Tests
```bash
# Run all tests
npm test

# Type checking
npm run typecheck
```
### Testing Setup Locally
```bash
# Test CI mode without actually installing
CI=true npm run ci:setup
```

## Customization

1. **Shell Configuration**: Edit `zsh/.zshrc` for ZSH customizations
2. **Tmux**: Modify `tmux/.tmux.conf` for tmux settings
3. **Starship Prompt**: Customize `.config/starship.toml`
4. **Package List**: Update `brew_packages.txt` with your preferred tools

## Troubleshooting

### Setup Issues
- Check `~/.dotfiles_backup/` for backed up files
- Ensure Xcode Command Line Tools are installed: `xcode-select --install`

## License

MIT License - See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Acknowledgments

This setup is inspired by the dotfiles community and includes configurations adapted from various sources. Special thanks to all the creators of the amazing tools included in this setup.
