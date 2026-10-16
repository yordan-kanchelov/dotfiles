#!/bin/bash
# Runs inside Ubuntu as its normal user. All tool/config provisioning is Ansible.
set -euo pipefail
repository=$1
ref=$2
shift 2
if [[ $(id -u) == 0 ]]; then
  echo 'Create a normal Ubuntu user and rerun; do not bootstrap as root.' >&2
  exit 1
fi
if ! command -v git >/dev/null; then
  sudo apt-get update
  sudo apt-get install -y git ca-certificates
fi
checkout="$HOME/dotfiles"
if [[ ! -e "$checkout" ]]; then
  git clone --branch "$ref" -- "$repository" "$checkout"
else
  [[ -d "$checkout/.git" ]] || { echo "$checkout is not a Git checkout" >&2; exit 1; }
  [[ -z $(git -C "$checkout" status --porcelain) ]] || { echo "$checkout has local changes; commit or stash them before rerunning" >&2; exit 1; }
  [[ $(git -C "$checkout" remote get-url origin) == "$repository" ]] || { echo "$checkout uses a different origin; inspect it before rerunning" >&2; exit 1; }
  [[ $(git -C "$checkout" branch --show-current) == "$ref" ]] || { echo "$checkout is on another branch; select $ref before rerunning" >&2; exit 1; }
  git -C "$checkout" fetch origin "$ref"
  git -C "$checkout" merge --ff-only FETCH_HEAD
fi
cd "$checkout"
# Ansible logs persist across console closure/restarts, without storing passwords.
umask 077
state_dir="$HOME/.local/state/dotfiles"
mkdir -p "$state_dir"
chmod 700 "$state_dir"
export ANSIBLE_LOG_PATH="$state_dir/ansible-setup.log"
touch "$ANSIBLE_LOG_PATH"
chmod 600 "$ANSIBLE_LOG_PATH"
printf 'Ansible log: %s\n' "$ANSIBLE_LOG_PATH"
bash ./bootstrap.sh "$@"
exec ansible-playbook windows.yml
