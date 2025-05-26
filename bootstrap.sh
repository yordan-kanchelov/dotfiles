#!/bin/bash
# Bootstrap script to ensure Node.js is available via fnm
set -euo pipefail

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}Bootstrapping Node.js environment...${NC}"

# Function to detect shell configuration file
detect_shell_config() {
  if [ -n "${BASH_VERSION:-}" ]; then
    if [ -f "$HOME/.bash_profile" ]; then
      echo "$HOME/.bash_profile"
    else
      echo "$HOME/.bashrc"
    fi
  elif [ -n "${ZSH_VERSION:-}" ]; then
    echo "$HOME/.zshrc"
  else
    echo "$HOME/.profile"
  fi
}

SHELL_CONFIG=$(detect_shell_config)

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
  else
    # Linux and others
    echo -e "${GREEN}Installing fnm via install script...${NC}"
    curl -fsSL https://fnm.vercel.app/install | bash
  fi

  # Add fnm to current shell session
  export PATH="$HOME/.fnm:$PATH"
  eval "$(fnm env --use-on-cd)"
else
  echo -e "${GREEN}fnm is already installed${NC}"
  # Ensure fnm is available in current session
  eval "$(fnm env --use-on-cd 2>/dev/null || true)"
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

# Check if running in CI
if [ -n "${CI:-}" ] || [ -n "${GITHUB_ACTIONS:-}" ]; then
  echo -e "${BLUE}CI environment detected. Bootstrap complete.${NC}"
else
  echo -e "${GREEN}Bootstrap complete! Running npm install...${NC}"
  npm install
fi

echo -e "${GREEN}You can now run: npm run setup${NC}"
