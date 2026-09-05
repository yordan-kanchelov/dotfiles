#!/bin/bash
# Installs prerequisites, then runs setup.yml on macOS/Debian. On Omarchy it
# prepares Ansible only; install-omarchy.sh owns selection and configuration.
set -euo pipefail
cd "$(dirname "$0")"

ensure_collection() {
  # pip/pipx ansible-core ships without community.general; apt/brew's `ansible` bundles it.
  # grep without -q drains the pipe, avoiding a pipefail/EPIPE false miss.
  ansible-galaxy collection list community.general 2>/dev/null | grep '^community.general ' >/dev/null ||
    ansible-galaxy collection install -r requirements.yml
}

os_release=${DOTFILES_OS_RELEASE:-/etc/os-release}
os_id=
os_like=
if [[ -r $os_release ]]; then
  # The path is fixed by the OS or an explicit test seam.
  # shellcheck disable=SC1090
  source "$os_release"
  os_id=${ID:-}
  os_like=${ID_LIKE:-}
fi

if [[ $os_id == omarchy ]]; then
  (($# == 0)) || { echo "Omarchy bootstrap accepts no arguments; use ./install-omarchy.sh" >&2; exit 1; }
  command -v omarchy >/dev/null || { echo "Omarchy public CLI is missing; repair Omarchy first" >&2; exit 1; }
  [[ -f ${OMARCHY_PATH:-/usr/share/omarchy}/default/hypr/bootstrap.lua ]] || {
    echo "Omarchy bootstrap marker is missing; repair Omarchy first" >&2
    exit 1
  }
  command -v ansible-playbook >/dev/null || omarchy pkg add ansible
  command -v ansible-playbook >/dev/null || { echo "Ansible installation failed" >&2; exit 1; }
  ensure_collection
  echo "Prerequisites ready. Next: ./install-omarchy.sh"
  exit 0
fi

case "$OSTYPE" in
  darwin*)
    if ! command -v brew >/dev/null; then
      NONINTERACTIVE="${CI:-}" /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
    command -v ansible-playbook >/dev/null || brew install ansible
    ;;
  linux-gnu*)
    case " $os_id $os_like " in
      *debian*|*ubuntu*|*linuxmint*) ;;
      *) echo "Debian/Ubuntu or Omarchy only" >&2; exit 1 ;;
    esac
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

ensure_collection
exec ansible-playbook setup.yml "$@"
