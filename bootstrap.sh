#!/bin/bash
# Installs Ansible (and Homebrew on macOS), then runs setup.yml. Extra arguments
# go straight to ansible-playbook:  ./bootstrap.sh --tags symlinks
set -euo pipefail
cd "$(dirname "$0")"

case "$OSTYPE" in
  darwin*)
    if ! command -v brew >/dev/null; then
      NONINTERACTIVE="${CI:-}" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    command -v ansible-playbook >/dev/null || brew install ansible
    ;;
  linux-gnu*)
    command -v apt-get >/dev/null || { echo "Debian/Ubuntu only" >&2; exit 1; }
    if ! command -v ansible-playbook >/dev/null; then
      sudo apt-get update -y && sudo apt-get install -y ansible
    fi
    # apt and usermod need sudo. Probe for it instead of keying on $CI: -K only
    # when sudo actually needs a password (CI runners and cached tickets don't).
    sudo -n true 2>/dev/null || set -- -K "$@"
    ;;
  *)
    echo "Unsupported OS: $OSTYPE" >&2
    exit 1
    ;;
esac

# pip/pipx ansible-core ships without community.general; apt/brew's `ansible` bundles it.
# grep without -q: it must drain the pipe, or pipefail can turn ansible-galaxy's
# EPIPE into a bogus miss that reinstalls the collection every run.
ansible-galaxy collection list community.general 2>/dev/null | grep '^community.general ' >/dev/null ||
  ansible-galaxy collection install -r requirements.yml

exec ansible-playbook setup.yml "$@"
