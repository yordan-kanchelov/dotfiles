#!/bin/bash

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d%H%M%S)"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default settings
INTERACTIVE=true
FORCE_OVERWRITE=false
APPEND_CONFIGS=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --non-interactive)
            INTERACTIVE=false
            shift
            ;;
        --force-overwrite)
            FORCE_OVERWRITE=true
            shift
            ;;
        --append)
            APPEND_CONFIGS=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Create backup directory if needed
mkdir -p "$BACKUP_DIR"

# Function to handle user interaction for file operations
prompt_user() {
    local message="$1"
    local default_choice="$2"
    
    if [ "$INTERACTIVE" = false ]; then
        # In non-interactive mode, return the default choice
        echo "$default_choice"
        return 0
    fi
    
    while true; do
        read -p "$message " -n 1 -r
        echo
        case $REPLY in
            [Yy]* ) echo "y"; return 0;;
            [Nn]* ) echo "n"; return 0;;
            * ) echo -e "${YELLOW}Please answer y or n.${NC}";;
        esac
    done
}

# Function to backup a file
backup_file() {
    local file_path="$1"
    local backup_path
    backup_path="$BACKUP_DIR/$(echo "$file_path" | sed 's|^/||;s|/|_|g').bak"
    
    if [ -e "$file_path" ]; then
        mkdir -p "$(dirname "$backup_path")"
        cp -r "$file_path" "$backup_path"
        echo -e "${BLUE}Backed up $file_path to $backup_path${NC}"
    fi
}

# Function to create or append to config files
handle_config_file() {
    local source_file="$1"
    local target_file="$2"
    # No local variables needed here
    
    # Check if we're in append mode first, as it handles both existing and new files
    if [ "$APPEND_CONFIGS" = true ]; then
        # Append mode - always append to the target file, whether it exists or not
        if [ ! -e "$target_file" ] && [ ! -L "$target_file" ]; then
            # If file doesn't exist, create it with the source content
            cp "$source_file" "$target_file"
            echo -e "${GREEN}Created new file: $target_file${NC}"
        else
            # If file exists or is a symlink, back it up and append
            backup_file "$target_file"
            echo -e "\n# Appended by dotfiles setup on $(date)" >> "$target_file"
            cat "$source_file" >> "$target_file"
            echo -e "${GREEN}Appended config to: $target_file${NC}"
        fi
        return 0
    fi
    
    # If target doesn't exist, create the symlink
    if [ ! -e "$target_file" ] && [ ! -L "$target_file" ]; then
        ln -sf "$source_file" "$target_file"
        echo -e "${GREEN}Created symlink: $target_file -> $source_file${NC}"
        return 0
    fi
    
    # If target is already our symlink, skip
    if [ -L "$target_file" ] && [ "$(readlink "$target_file" 2>/dev/null)" = "$source_file" ]; then
        echo -e "${GREEN}Symlink already exists: $target_file -> $source_file${NC}"
        return 0
    fi
    
    # Handle existing file
    echo -e "${YELLOW}File already exists: $target_file${NC}"
    
    if [ "$FORCE_OVERWRITE" = true ]; then
        # Force overwrite mode
        backup_file "$target_file"
        ln -sf "$source_file" "$target_file"
        echo -e "${GREEN}Overwrote: $target_file -> $source_file${NC}"
        return 0
    elif [ "$INTERACTIVE" = true ]; then
        # Interactive mode
        echo -e "${BLUE}What would you like to do with $target_file?${NC}"
        echo "1) Overwrite (backup will be created)"
        echo "2) Append to existing file"
        echo "3) Skip this file"
        echo -n "[1-3] (default: 1) "
        
        read -r choice
        case $choice in
            2)
                backup_file "$target_file"
                echo -e "\n# Appended by dotfiles setup on $(date)" >> "$target_file"
                cat "$source_file" >> "$target_file"
                echo -e "${GREEN}Appended config to: $target_file${NC}"
                ;;
            3)
                echo -e "${YELLOW}Skipped: $target_file${NC}"
                ;;
            *)
                backup_file "$target_file"
                ln -sf "$source_file" "$target_file"
                echo -e "${GREEN}Overwrote: $target_file -> $source_file${NC}"
                ;;
        esac
    else
        # Non-interactive, non-force mode - skip
        echo -e "${YELLOW}Skipped: $target_file (use --force-overwrite or --append to modify)${NC}"
    fi
}

# Function to create symlinks
create_symlink() {
    local source_file="$1"
    local target_file="$2"
    
    # Skip if source doesn't exist
    if [ ! -e "$source_file" ]; then
        echo -e "${YELLOW}Source file not found: $source_file - skipping${NC}"
        return 0
    fi
    
    # Handle config files that might need special treatment
    if [[ "$target_file" == *".zshrc" || "$target_file" == *".bashrc" || "$target_file" == *".bash_profile" ]]; then
        handle_config_file "$source_file" "$target_file"
    else
        # For other files, use standard symlink behavior
        if [ -e "$target_file" ] || [ -L "$target_file" ]; then
            if [ "$FORCE_OVERWRITE" = true ] || [ "$(prompt_user "Overwrite $target_file? [y/N]" "n")" = "y" ]; then
                backup_file "$target_file"
                ln -sf "$source_file" "$target_file"
                echo -e "${GREEN}Created symlink: $target_file -> $source_file${NC}"
            else
                echo -e "${YELLOW}Skipped: $target_file${NC}"
            fi
        else
            ln -sf "$source_file" "$target_file"
            echo -e "${GREEN}Created symlink: $target_file -> $source_file${NC}"
        fi
    fi
}

# Function to install required packages using Homebrew (macOS only)
install_packages() {
    # Check if running on macOS
    if [[ "$OSTYPE" != "darwin"* ]]; then
        echo -e "${YELLOW}Warning: This script is optimized for macOS. Some features may not work on this platform.${NC}"
        return 0
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
            echo "eval \"$(/opt/homebrew/bin/brew shellenv)\"" >> "$HOME/.zprofile"
        else
            # Intel Mac
            eval "$(/usr/local/bin/brew shellenv)"
            echo "eval \"$(/usr/local/bin/brew shellenv)\"" >> "$HOME/.zprofile"
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
    
    if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
        echo -e "${GREEN}Installing TPM...${NC}"
        mkdir -p "$HOME/.tmux/plugins"
        git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
    else
        echo -e "${GREEN}TPM is already installed${NC}"
    fi
}

# Function to automatically install tmux plugins
install_tmux_plugins() {
    echo -e "${GREEN}Installing tmux plugins automatically...${NC}"
    
    # Check if running in CI environment
    if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
        echo -e "${YELLOW}Detected CI environment. Skipping plugin installation.${NC}"
        echo -e "${YELLOW}In production, run 'tmux' and press 'prefix + I' to install plugins.${NC}"
        return 0
    fi
    
    # Check if TPM is installed
    if [ -f "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
        # First check if tmux command exists
        if command -v tmux &> /dev/null; then
            # Run the TPM install script but don't fail if it doesn't work
            ("$HOME/.tmux/plugins/tpm/bin/install_plugins" > /dev/null 2>&1) || \
            echo -e "${YELLOW}Run 'tmux' and then press 'prefix + I' to install tmux plugins manually${NC}"
        else
            echo -e "${YELLOW}tmux command not found, skipping plugin installation${NC}"
        fi
    else
        echo -e "${YELLOW}TPM not installed or not found, skipping plugin installation${NC}"
    fi
}

# Function to source zshrc
source_zshrc() {
    echo -e "${GREEN}Attempting to source .zshrc...${NC}"
    if command -v zsh &> /dev/null; then
        # Execute zsh and attempt to source the zshrc
        # Use || true to prevent script from failing if commands in zshrc fail
        zsh -c "source ~/.zshrc 2>/dev/null || true && echo -e '${GREEN}zshrc sourced successfully!${NC}'" || \
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
create_symlink "$DOTFILES_DIR/.config/atuin" "$HOME/.config/atuin"

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
