# 0004. Debian-family host setup

Status: Accepted, 2026-11-20

## Context

`tasks/debian.yml` covers Debian, Ubuntu and Linux Mint. Some of its tasks need root and some must not have it, and the ollama service has to work without a system unit.

## Decision

- The become tasks run first, so a single sudo ticket covers all of them.
- The login shell changes to zsh with `usermod`. Debian creates accounts with bash, so every zsh config this repository links would sit inert otherwise. `usermod` does not consult `/etc/shells`.
- The Linuxbrew prefix is created ahead of time and owned by the user. Homebrew's installer refuses to run as root and calls sudo itself, which is invisible under Ansible. When the prefix already exists and is writable, the installer skips sudo entirely.
- ollama's bundle keeps its libraries next to the binary, so `~/.local/bin` gets a link to it, not a copy. The link uses `force`: a real file left there by ollama's own installer must not abort the play after the 1.4 GB download has already happened.
- ollama runs as a systemd *user* unit, not a system one. It needs no sudo, and the daemon follows the login session.
- The service task checks `XDG_RUNTIME_DIR`. `systemctl --user` needs a live user manager, and PID 1 being systemd says nothing about that: su, ssh without PAM, and cron all fail with "Failed to connect to bus". When the unit changes, the service is restarted. `started` alone would leave a running daemon on the old unit forever.

## Consequences

Run the playbook with `-K` on Linux. A machine without a user systemd session gets the ollama files but no running service.
