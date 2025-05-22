#!/bin/bash

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d%H%M%S)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Create backup directory if needed
mkdir -p "$BACKUP_DIR"

# Function to create symlinks
create_symlink() {
    local source_file="$1"
    local target_file="$2"

    # Create parent directories if they don't exist
    mkdir -p "$(dirname "$target_file")"

    # Skip if source file doesn't exist
    if [ ! -e "$source_file" ]; then
        echo -e "${YELLOW}Source file not found: $source_file - skipping${NC}"
        return 0
    fi

    # Skip if target is already a symlink pointing to the correct location
    if [ -L "$target_file" ] && [ "$(readlink "$target_file" 2>/dev/null)" = "$source_file" ]; then
        echo -e "${GREEN}Symlink already exists: $target_file -> $source_file${NC}"
        return 0
    fi

    # Backup existing file if it exists and is not a symlink to our source
    if [ -e "$target_file" ]; then
        echo -e "${YELLOW}Backing up existing $target_file to $BACKUP_DIR${NC}"
        mkdir -p "$BACKUP_DIR/$(dirname "$target_file")"
        mv "$target_file" "$BACKUP_DIR/$(basename "$target_file")" 2>/dev/null || true
    fi

    # Create the symlink
    ln -sf "$source_file" "$target_file"
    echo -e "${GREEN}Created symlink: $target_file -> $source_file${NC}"
    return 0
}

# Function to install required packages using Homebrew (macOS only)
install_packages() {
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${RED}Error: This script is only supported on macOS.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Installing required packages with Homebrew...${NC}"

    # Install Homebrew if not installed
    if ! command -v brew &> /dev/null; then
        echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${NC}"
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Set up Homebrew in the current shell
        if [[ -f /opt/homebrew/bin/brew ]]; then
            # Apple Silicon Mac
            eval "$(/opt/homebrew/bin/brew shellenv)"
            echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        else
            # Intel Mac
            eval "$(/usr/local/bin/brew shellenv)"
            echo 'eval "$(/usr/local/bin/brew shellenv)"' >> "$HOME/.zprofile"
        fi
        
        echo -e "${GREEN}Homebrew installed and added to PATH${NC}"
    fi

    # Install required packages from brew_packages.txt
    echo -e "${GREEN}Installing packages from brew_packages.txt...${NC}"
    if [ -f "$DOTFILES_DIR/brew_packages.txt" ]; then
        while IFS= read -r package; do
            # Skip empty lines and comments
            if [[ -n "$package" && ! "$package" =~ ^[[:space:]]*# ]]; then
                echo -e "${GREEN}Installing $package...${NC}"
                brew install "$package" || echo -e "${YELLOW}Failed to install $package${NC}"
            fi
        done < "$DOTFILES_DIR/brew_packages.txt"
    else
        echo -e "${RED}Error: brew_packages.txt not found in $DOTFILES_DIR${NC}"
        echo -e "${YELLOW}Falling back to default packages...${NC}"
        brew install tmux bat
    fi
}

# Function to install tmux plugin manager
install_tpm() {
    echo -e "${GREEN}Setting up Tmux Plugin Manager (TPM)...${NC}"
    TPM_DIR="$HOME/.tmux/plugins/tpm"

    if [ -d "$TPM_DIR" ]; then
        echo -e "${YELLOW}TPM already installed, updating...${NC}"
        (cd "$TPM_DIR" && git pull)
    else
        echo -e "${GREEN}Installing TPM...${NC}"
        mkdir -p "$(dirname "$TPM_DIR")"
        git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
    fi
}

# Function to automatically install tmux plugins
install_tmux_plugins() {
    echo -e "${GREEN}Installing tmux plugins automatically...${NC}"
    if [ -f "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
        # Install plugins in a non-interactive way
        "$HOME/.tmux/plugins/tpm/bin/install_plugins"
        echo -e "${GREEN}Tmux plugins installed successfully!${NC}"
    else
        echo -e "${RED}TPM install_plugins script not found${NC}"
        echo -e "${YELLOW}Run 'tmux' and then press 'prefix + I' to install tmux plugins manually${NC}"
    fi
}

# Function to source zshrc
source_zshrc() {
    echo -e "${GREEN}Attempting to source .zshrc...${NC}"
    if command -v zsh &> /dev/null; then
        # Execute zsh and attempt to source the zshrc
        zsh -c "source ~/.zshrc && echo -e '${GREEN}zshrc sourced successfully!${NC}'" ||
        echo -e "${YELLOW}Couldn't automatically source .zshrc${NC}"
    else
        echo -e "${YELLOW}zsh shell not found. Please run 'source ~/.zshrc' manually${NC}"
    fi
}

# Main script execution
echo -e "${GREEN}Setting up dotfiles...${NC}"

# Install required packages
install_packages

# Install tmux plugin manager
install_tpm

# Create symlinks
echo -e "${GREEN}Creating symlinks...${NC}"

# Create config directory if it doesn't exist
mkdir -p "$HOME/.config"

# Create symlinks for config files
create_symlink "$DOTFILES_DIR/.config/ghostty" "$HOME/.config/ghostty"
create_symlink "$DOTFILES_DIR/.config/starship.toml" "$HOME/.config/starship.toml"

# Create symlinks for dotfiles in home directory
create_symlink "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/tmux/.tmux.conf" "$HOME/.tmux.conf"

# Source zsh configuration
source_zshrc

# Install tmux plugins
install_tmux_plugins

echo -e "${GREEN}Setup completed successfully!${NC}"
echo -e "${GREEN}All dotfiles are linked and tools are installed!${NC}"
echo -e "${YELLOW}NOTE: If you'd like to try your new settings, you can run 'zsh' to start a new shell${NC}"
