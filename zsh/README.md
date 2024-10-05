
# Zsh Configuration with Powerlevel10k and Essential Tools

## Overview

This README provides an overview of the tools required to utilize the provided `.zshrc` configuration for Zsh. The configuration includes Powerlevel10k for a powerful prompt, Atuin for efficient command history management, fnm for Node.js version management, and convenient aliases.

## Required Tools

To make full use of the configuration, ensure the following tools are installed:

- **Zinit**: A flexible and fast Zsh plugin manager.
- **Powerlevel10k**: A fast and customizable Zsh theme.
- **Atuin**: Enhanced shell history management.
- **fnm (Fast Node Manager)**: Efficient Node.js version manager.
- **Neovim**: An extensible Vim-based text editor.
- **Tmux**: Terminal multiplexer for managing multiple sessions.

## Installation

Below are the general steps to install the required tools on **Ubuntu/Debian** and **macOS** systems.

### Zinit

Install Zinit to manage Zsh plugins and themes.

```bash
bash -c "$(curl -fsSL https://git.io/zinit-install)"
```

### Powerlevel10k

Install Powerlevel10k using Zinit.

Since the `.zshrc` already includes the necessary configuration, you just need to ensure the theme is installed:

```bash
# Ensure Zinit is initialized (already in .zshrc)
source "$HOME/.local/share/zinit/zinit.zsh"

# Install Powerlevel10k theme
zinit light romkatv/powerlevel10k
```

### Atuin

Install Atuin for enhanced shell history management.

**Ubuntu/Debian:**

```bash
curl -s https://raw.githubusercontent.com/ellie/atuin/main/install.sh | bash
```

**macOS (using Homebrew):**

```bash
brew install atuin
```

### fnm (Fast Node Manager)

Install fnm for Node.js version management.

```bash
curl -fsSL https://fnm.vercel.app/install | bash
```

### Neovim

Install Neovim if needed.

**Ubuntu/Debian:**

```bash
sudo apt install neovim
```

**macOS:**

```bash
brew install neovim
```

### Tmux

Install Tmux for terminal multiplexing.

**Ubuntu/Debian:**

```bash
sudo apt install tmux
```

**macOS:**

```bash
brew install tmux
```

## Aliases and Configurations

The configuration includes several aliases and environment variables. Since you're using the provided `.zshrc`, these are already set up.

### General Aliases

- **`ghcs`**: Shortcut for `gh copilot suggest`.

### Tmux Aliases

Shortcuts for common Tmux commands:

- **`ta`**: Attach to a Tmux session.
- **`tn`**: Create a new Tmux session.
- **`tls`**, **`tlist`**: List Tmux sessions.
- **`tk`**, **`tkill`**: Kill a Tmux session or the server.
- **`tren`**: Rename a Tmux session.
- **`tnw`**: Open a new Tmux window.
- **`th`**, **`tv`**: Split Tmux window horizontally or vertically.
- **`tkp`**: Kill a Tmux pane.

### WSL Aliases (For Windows Users)

Aliases to interact with Windows applications from WSL:

- **`explorer`**, **`open`**: Open Windows Explorer.
- **`kubectl`**: Use Windows-installed `kubectl`.

### Environment Variables

- **Neovim Path**: If Neovim is installed in a custom location, its path is added to `PATH`.
- **fnm Initialization**: Initializes `fnm` and sets up the environment for Node.js version management.

## Final Steps

After installing the required tools, reload your shell to apply the configurations:

```bash
source ~/.zshrc
```

## License

This configuration is provided as-is without any warranty. Feel free to modify and distribute.
