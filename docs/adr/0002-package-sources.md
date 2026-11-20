# 0002. Where packages and fonts come from

Status: Accepted, 2026-11-20

## Context

The playbook supports macOS and Debian-family Linux. Each has its own native package manager, and the two disagree on versions, package names and binary formats.

## Decision

### Homebrew for CLI tools, apt for the base system (`vars/Debian.yml`, `tasks/debian.yml`)

- On Linux, Homebrew supplies the CLI tools in `brew_packages.yml`. Ubuntu 24.04's apt is years behind (neovim 0.9.5 against 0.12, fd 9 against 10).
- apt installs only the base system and what Homebrew's installer needs (build-essential, curl, git). A tool must never come from both. A second apt copy is an older build, sometimes under another name (`batcat`, `fdfind`), and which copy runs would depend on PATH order.
- `brew_linux_excluded` lists formulae that brew must not install on Linux, checked against the homebrew-core API. `tart`, `telnet` and `pipx` have no Linux bottle; tart runs Apple Silicon VMs. apt supplies `telnet` and `pipx` instead, so both stay in the apt list. `ollama` has a Linux bottle, but it is CPU-only (see below). `duti` sets macOS default apps.
- Other apt entries: `fontconfig` provides `fc-cache`, which minimal installs lack; `unzip` unpacks the Nerd Fonts archives; `zstd` lets tar read ollama's `.tar.zst`.
- `deb_arch` maps the arches it knows and passes unknown ones through by name. A download then fails with the real arch in the error, rather than fetching an arm64 binary that cannot run.

### ollama from the upstream tarball (`tasks/debian.yml`)

- Homebrew's Linux bottle has only the CPU runner, so brew's ollama runs 27B models at about 5 tok/s while a 3090 sits idle. The upstream tarball includes the CUDA runners. It is a 1.4 GB download and needs a user systemd instance. Skip it with `--skip-tags ollama`.

### Formula details (`brew_packages.yml`, `setup.yml`)

- `tree-sitter-cli`, not `tree-sitter`. nvim-treesitter needs the `tree-sitter` command, and the `tree-sitter` formula ships only the library.
- Formulae from a tap (such as `cirruslabs/cli/tart`) skip `community.general.homebrew` and go through `brew tap` and `brew install`. The module fails on any stderr from `brew info`, and taps print deprecation warnings. Newer brews refuse formulae from untrusted taps (tart pulls softnet from its own tap), so the tap is trusted first. Error handling and the `creates` guard are a known workaround: [yordan-kanchelov/dotfiles#19](https://github.com/yordan-kanchelov/dotfiles/issues/19).
- `requirements.yml` lists `community.general`. The apt and brew `ansible` packages already bundle it. `bootstrap.sh` installs it for a bare `ansible-core` from pip or pipx, and ansible-lint in CI installs from this file.

### macOS default apps (`vars/Darwin.yml`, `setup.yml`)

- Source and config files open in VS Code, both from Finder and from a cmd+click on a `file://` link in Ghostty (the open-in-editor Claude mod renders reply paths as those links).
- Handlers are set by UTI. duti's extension form reports success while macOS keeps the old handler. macOS treats `.ts` as `public.mpeg-2-transport-stream`, so MPEG-TS videos open in VS Code too.
- The task waits until both duti (from packages) and VS Code (installed by hand) are present.

### Fonts (`setup.yml`, `bootstrap.ps1`)

- The 0xProto, FiraCode and RobotoMono families come from the Nerd Fonts release and are not vendored; together they are about 150 MB of binaries.
- They are installed as real files, not symlinks: macOS CoreText is unreliable with symlinked faces in `~/Library/Fonts`.
- `creates` checks one face per family. A family that is already installed is neither downloaded nor replaced.
- The playbook downloads `.zip`, not `.tar.xz`. `unarchive` needs GNU tar for tarballs, and macOS ships bsdtar.
- Only `*.ttf` is extracted. Each archive also contains a README and a licence, which would collide across families.
- The fonts directory is created without a `mode`, because copy and unarchive do not create parent directories and `~/Library/Fonts` already exists as 0700.

## Consequences

Linux machines depend on Homebrew for every everyday tool. A tool missing from brew has to be added deliberately to the apt list and to `brew_linux_excluded`, never to both package lists.
