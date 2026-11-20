#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

os_id=
os_like=
if [[ -r /etc/os-release ]]; then
  # shellcheck source=/dev/null
  source /etc/os-release
  os_id=${ID:-}
  os_like=${ID_LIKE:-}
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
    bootstrap_sudo=sudo
    case " $os_id $os_like " in
      *" omarchy "*)
        command -v ansible-playbook >/dev/null || omarchy pkg add ansible
        ;;
      *debian*|*ubuntu*|*linuxmint*)
        if [[ -x /usr/bin/sudo.ws ]]; then bootstrap_sudo=/usr/bin/sudo.ws; fi
        command -v apt-get >/dev/null || { echo "Debian/Ubuntu only" >&2; exit 1; }
        if ! command -v ansible-playbook >/dev/null; then
          "$bootstrap_sudo" apt-get update -y && "$bootstrap_sudo" apt-get install -y ansible
        fi
        ;;
      *) echo "Debian/Ubuntu or Omarchy only" >&2; exit 1 ;;
    esac
    "$bootstrap_sudo" -n -k true 2>/dev/null || set -- -K "$@"
    ;;
  *)
    echo "Unsupported OS: $OSTYPE" >&2
    exit 1
    ;;
esac

ansible-galaxy collection list community.general 2>/dev/null | grep '^community.general ' >/dev/null ||
  ansible-galaxy collection install -r requirements.yml

exec ansible-playbook setup.yml "$@"
