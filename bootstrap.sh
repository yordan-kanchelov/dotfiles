#!/bin/bash
# Bootstrap script to ensure Node.js is available via fnm
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Install Homebrew if not present (macOS only)
if [[ "$OSTYPE" == "darwin"* ]]; then
  if ! command -v brew &> /dev/null; then
    echo -e "${YELLOW}Homebrew not found. Installing Homebrew...${NC}"
    if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
      NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    else
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi

    # Add brew to PATH for current session
    # Note: Permanent PATH setup is handled by dotfiles .zprofile
    if [ -f "/opt/homebrew/bin/brew" ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -f "/usr/local/bin/brew" ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
    echo -e "${GREEN}Homebrew installed successfully${NC}"
  else
    echo -e "${GREEN}Homebrew is already installed${NC}"
  fi
fi

# Install zsh and build dependencies on Linux
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  if ! command -v zsh &> /dev/null; then
    echo -e "${YELLOW}zsh not found. Installing zsh...${NC}"
    sudo apt-get update -y
    sudo apt-get install -y zsh
    echo -e "${GREEN}zsh installed successfully${NC}"
  else
    echo -e "${GREEN}zsh is already installed${NC}"
  fi

  # Set zsh as default shell if it isn't already
  if [ "$(basename "$SHELL")" != "zsh" ]; then
    zsh_path="$(command -v zsh)"
    if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
      echo -e "${BLUE}CI detected — skipping chsh (would set default shell to $zsh_path)${NC}"
    else
      echo -e "${YELLOW}Setting zsh as default shell...${NC}"
      chsh -s "$zsh_path"
      echo -e "${GREEN}Default shell set to zsh. Log out and back in for it to take effect.${NC}"
    fi
  fi
fi

echo -e "${BLUE}Bootstrapping Node.js environment...${NC}"

# Function to detect shell configuration file
# Currently unused but kept for potential future use
# detect_shell_config() {
#   if [ -n "${BASH_VERSION:-}" ]; then
#     if [ -f "$HOME/.bash_profile" ]; then
#       echo "$HOME/.bash_profile"
#     else
#       echo "$HOME/.bashrc"
#     fi
#   elif [ -n "${ZSH_VERSION:-}" ]; then
#     echo "$HOME/.zshrc"
#   else
#     echo "$HOME/.profile"
#   fi
# }

# Check if fnm is installed
if ! command -v fnm &> /dev/null; then
  echo -e "${YELLOW}fnm not found. Installing fnm...${NC}"

  # Install fnm based on OS
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - check for Homebrew first
    if command -v brew &> /dev/null; then
      echo -e "${GREEN}Installing fnm via Homebrew...${NC}"
      brew install fnm
    else
      echo -e "${GREEN}Installing fnm via install script...${NC}"
      curl -fsSL https://fnm.vercel.app/install | bash
    fi
  elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo -e "${GREEN}Installing build dependencies for Linux...${NC}"
    sudo apt-get install -y curl unzip build-essential
    echo -e "${GREEN}Installing fnm via install script...${NC}"
    curl -fsSL https://fnm.vercel.app/install | bash
  else
    echo -e "${GREEN}Installing fnm via install script...${NC}"
    curl -fsSL https://fnm.vercel.app/install | bash
  fi

  # Add fnm to current shell session
  # Try common fnm installation paths
  if [ -d "$HOME/.local/share/fnm" ]; then
    export PATH="$HOME/.local/share/fnm:$PATH"
  elif [ -d "$HOME/.fnm" ]; then
    export PATH="$HOME/.fnm:$PATH"
  fi

  # Wait for fnm to be available
  if ! command -v fnm &> /dev/null; then
    echo -e "${YELLOW}Waiting for fnm to be available...${NC}"
    sleep 2
    # Try different possible fnm locations
    for fnm_path in "$HOME/.local/share/fnm/fnm" "$HOME/.fnm/fnm" "/opt/homebrew/bin/fnm" "/usr/local/bin/fnm"; do
      if [ -x "$fnm_path" ]; then
        fnm_dir=$(dirname "$fnm_path")
        export PATH="$fnm_dir:$PATH"
        break
      fi
    done
  fi

  if command -v fnm &> /dev/null; then
    # Don't use --use-on-cd yet as no Node versions are installed
    eval "$(fnm env --shell bash)"
  else
    echo -e "${RED}Error: fnm not found in PATH after installation${NC}"
    echo -e "${RED}PATH: $PATH${NC}"
    exit 1
  fi
else
  echo -e "${GREEN}fnm is already installed${NC}"
  # Ensure fnm is available in current session
  if command -v fnm &> /dev/null; then
    # Use fnm env without --use-on-cd to avoid errors if no Node version is installed
    eval "$(fnm env --shell bash 2>/dev/null || true)"
  else
    echo -e "${RED}Error: fnm command not found after installation${NC}"
    exit 1
  fi
fi

# Install Node.js 22+ if not already installed
NODE_VERSION="22"
CURRENT_VERSION=$(fnm current 2>/dev/null || echo "none")

if [[ "$CURRENT_VERSION" == "none" ]] || [[ ! "$CURRENT_VERSION" =~ ^v2[2-9]\. ]] && [[ ! "$CURRENT_VERSION" =~ ^v[3-9][0-9]\. ]]; then
  echo -e "${YELLOW}Installing Node.js v${NODE_VERSION}...${NC}"
  fnm install ${NODE_VERSION}
  fnm use ${NODE_VERSION}
  fnm default ${NODE_VERSION}
else
  echo -e "${GREEN}Node.js is already installed via fnm: $(fnm current)${NC}"
fi

# Verify Node.js and npm are available
if command -v node &> /dev/null && command -v npm &> /dev/null; then
  echo -e "${GREEN}Node.js $(node --version) and npm $(npm --version) are ready${NC}"
else
  echo -e "${RED}Error: Node.js or npm not found after installation${NC}"
  exit 1
fi

# Create .nvmrc file for consistency
echo "22" > .nvmrc
echo -e "${GREEN}Created .nvmrc file with Node.js 22${NC}"

# Add fnm --use-on-cd to shell config if not present
add_fnm_env_to_shell_config() {
  local shell_name config_file fnm_env_line
  shell_name="$(basename "$SHELL")"
  if [ "$shell_name" = "bash" ]; then
    config_file="$HOME/.bashrc"
    fnm_env_line='eval "$(fnm env --use-on-cd --shell bash)"'
  elif [ "$shell_name" = "zsh" ]; then
    config_file="$HOME/.zshrc"
    fnm_env_line='eval "$(fnm env --use-on-cd --shell zsh)"'
  else
    return 0
  fi

  if ! grep -Fq "$fnm_env_line" "$config_file" 2>/dev/null; then
    echo -e "${BLUE}Adding fnm --use-on-cd to $config_file...${NC}"
    echo -e "\n# Enable fnm automatic Node version switching\n$fnm_env_line" >> "$config_file"
  fi
}

add_fnm_env_to_shell_config

# Immediately enable fnm use-on-cd for current session
shell_name="$(basename "$SHELL")"
if [ "$shell_name" = "bash" ]; then
  eval "$(fnm env --use-on-cd --shell bash)"
elif [ "$shell_name" = "zsh" ]; then
  eval "$(fnm env --use-on-cd --shell zsh)"
fi

# Check if running in CI
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
  echo -e "${BLUE}CI environment detected. Bootstrap complete.${NC}"
else
  echo -e "${GREEN}Bootstrap complete! Running npm install...${NC}"
  npm install
fi

echo -e "${GREEN}You can now run: npm run setup${NC}"
