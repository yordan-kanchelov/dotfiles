#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$repo"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'EOF'
Usage: ./install-omarchy.sh [options]

  --components zsh,yazi|zsh|yazi|none
  --optional-tools shellcheck,git-lfs,glow,viu,act,pandoc-cli|none
  --node-manager mise|fnm
  --fnm-node VERSION
  --config yes|no
  --backup-dir ABSOLUTE_PATH
  --non-interactive
  --yes
  --dry-run
  --help
EOF
}

components_csv=zsh,yazi
optional_csv=shellcheck
node_manager=mise
fnm_node=
config=yes
backup_dir=
non_interactive=false
assume_yes=false
dry_run=false
declare -A seen=()

set_option() {
  local name=$1 value=$2
  if [[ ${seen[$name]+set} && ${seen[$name]} != "$value" ]]; then
    die "conflicting duplicate --${name//_/-} values"
  fi
  seen[$name]=$value
  printf -v "$name" '%s' "$value"
}

while (($#)); do
  case $1 in
    --components|--optional-tools|--node-manager|--fnm-node|--config|--backup-dir)
      (($# >= 2)) || die "$1 requires a value"
      value=$2
      case $1 in
        --components) set_option components_csv "$value" ;;
        --optional-tools) set_option optional_csv "$value" ;;
        --node-manager) set_option node_manager "$value" ;;
        --fnm-node) set_option fnm_node "$value" ;;
        --config) set_option config "$value" ;;
        --backup-dir) set_option backup_dir "$value" ;;
      esac
      shift 2
      ;;
    --non-interactive) non_interactive=true; shift ;;
    --yes) assume_yes=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    --help) usage; exit 0 ;;
    --*) die "unknown option: $1" ;;
    *) die "positional arguments are not supported: $1" ;;
  esac
done

validate_csv() {
  local value=$1 kind=$2 item allowed allowed_value duplicate
  shift 2
  local -a allowed_values=("$@") raw=()
  local -A found=()
  [[ -n $value ]] || die "$kind cannot be empty"
  if [[ $value == none ]]; then
    return
  fi
  [[ $value != *none* ]] || die "$kind cannot combine none with another value"
  IFS=, read -r -a raw <<< "$value"
  ((${#raw[@]})) || die "$kind cannot be empty"
  for item in "${raw[@]}"; do
    allowed=false
    for allowed_value in "${allowed_values[@]}"; do
      [[ $item == "$allowed_value" ]] && allowed=true
    done
    $allowed || die "invalid $kind value: $item"
    duplicate=${found[$item]:-false}
    $duplicate && die "duplicate $kind value: $item"
    found[$item]=true
  done
}

validate_csv "$components_csv" components zsh yazi
validate_csv "$optional_csv" optional-tools shellcheck git-lfs glow viu act pandoc-cli
[[ $node_manager == mise || $node_manager == fnm ]] || die "invalid node manager: $node_manager"
[[ $config == yes || $config == no ]] || die "config must be yes or no"
[[ -z $fnm_node || $node_manager == fnm ]] || die "--fnm-node requires --node-manager fnm"
[[ -z $fnm_node || $fnm_node =~ ^[0-9]+([.][0-9]+){0,2}$ ]] || die "invalid fnm Node version: $fnm_node"
if $non_interactive && ! $dry_run && ! $assume_yes; then
  die "mutating --non-interactive runs require --yes"
fi
if $non_interactive && [[ $node_manager == fnm && -z $fnm_node ]]; then
  die "non-interactive fnm selection requires --fnm-node"
fi

os_release=${DOTFILES_OS_RELEASE:-/etc/os-release}
[[ -r $os_release ]] || die "cannot read $os_release"
ID=
# Fixed OS path or explicit test seam.
# shellcheck disable=SC1090
source "$os_release"
[[ ${ID:-} == omarchy ]] || die "install-omarchy.sh requires ID=omarchy"
omarchy_path=${OMARCHY_PATH:-/usr/share/omarchy}
base_manifest="$omarchy_path/install/omarchy-base.packages"
[[ -f $omarchy_path/default/hypr/bootstrap.lua ]] || die "Omarchy bootstrap marker is missing"
command -v omarchy >/dev/null || die "Omarchy public CLI is missing"
[[ -r $base_manifest ]] || die "Omarchy base package manifest is missing: $base_manifest"
command -v ansible-playbook >/dev/null || die "Ansible is missing; run ./bootstrap.sh first"

backup_root=$(realpath -m "$HOME/.dotfiles_backup")
if [[ -z $backup_dir ]]; then
  backup_dir="$backup_root/omarchy-$(date +%Y%m%d-%H%M%S)"
fi
[[ $backup_dir == /* ]] || die "--backup-dir must be absolute"
backup_dir=$(realpath -m "$backup_dir")
[[ $backup_dir == "$backup_root"/* ]] || die "--backup-dir must be beneath $backup_root"
receipt="$backup_dir/omarchy-install.receipt"

mise_node_path=
if command -v mise >/dev/null && mise_node_path=$(mise where node 2>/dev/null); then
  mise_active=true
else
  mise_active=false
  mise_node_path=none
fi
if omarchy pkg present fnm >/dev/null 2>&1 || command -v fnm >/dev/null 2>&1; then
  fnm_present=true
else
  fnm_present=false
fi

catalog=(omarchy-zsh yazi shellcheck git-lfs glow viu act pandoc-cli fnm)
base_owns() {
  local package=$1
  awk -v package="$package" '
    { sub(/[[:space:]]*#.*/, ""); gsub(/^[[:space:]]+|[[:space:]]+$/, "") }
    $0 == package { found=1 }
    END { exit found ? 0 : 1 }
  ' "$base_manifest"
}

gum=${DOTFILES_GUM:-gum}
if ! $non_interactive; then
  command -v "$gum" >/dev/null || die "Gum is missing; repair Omarchy or use --non-interactive --yes"

  printf 'Target: %s\nBase manifest: %s\n' "$omarchy_path" "$base_manifest"
  for package in "${catalog[@]}"; do
    if base_owns "$package"; then
      state=base-owned
    elif omarchy pkg present "$package" >/dev/null 2>&1; then
      state=present
    else
      state=missing
    fi
    printf 'Package %-14s %s\n' "$package" "$state"
  done
  if $mise_active; then
    printf 'Active Node owner: Mise (%s)\n' "$mise_node_path"
  else
    printf 'Active Node owner: none detected\n'
  fi
  for target in .zshrc .zprofile .config/dotfiles/zsh/personal.zsh \
    .config/dotfiles/starship.toml .config/yazi; do
    if [[ -e $HOME/$target || -L $HOME/$target ]]; then
      state=present
    else
      state=absent
    fi
    printf 'Config target %-43s %s\n' "$HOME/$target" "$state"
  done

  if ! choice=$("$gum" choose --no-limit --header 'Core defaults' --selected 'Zsh overlay' --selected Yazi \
    'Zsh overlay' Yazi); then
    die "component selection cancelled"
  fi
  components_csv=none
  if grep -Fxq 'Zsh overlay' <<< "$choice"; then
    components_csv=zsh
  fi
  if grep -Fxq Yazi <<< "$choice"; then
    if [[ $components_csv == none ]]; then
      components_csv=yazi
    else
      components_csv+=,yazi
    fi
  fi

  if ! choice=$("$gum" choose --no-limit --header 'Optional tools' --selected ShellCheck \
    ShellCheck git-lfs glow viu act pandoc-cli); then
    die "optional-tool selection cancelled"
  fi
  optional_csv=none
  for label in ShellCheck git-lfs glow viu act pandoc-cli; do
    if grep -Fxq "$label" <<< "$choice"; then
      package=${label/ShellCheck/shellcheck}
      if [[ $optional_csv == none ]]; then
        optional_csv=$package
      else
        optional_csv+=,$package
      fi
    fi
  done

  if ! choice=$("$gum" choose --header 'Node manager' \
    'Mise — recommended; preserve current Node' 'fnm — advanced; mutually exclusive'); then
    die "Node manager selection cancelled"
  fi
  case $choice in
    'Mise — recommended; preserve current Node') node_manager=mise ;;
    'fnm — advanced; mutually exclusive') node_manager=fnm ;;
    *) die "invalid Gum Node selection" ;;
  esac

  if [[ $node_manager == fnm ]]; then
    $mise_active && die "fnm cannot be selected while Mise owns Node at $mise_node_path"
    fnm_node=${fnm_node:-22}
    "$gum" confirm --default=false "Use fnm Node $fnm_node instead of Mise?" || die "fnm confirmation cancelled"
  fi

  if ! choice=$("$gum" choose --header 'Apply selected configuration?' --selected yes yes no); then
    die "configuration selection cancelled"
  fi
  [[ $choice == yes || $choice == no ]] || die "invalid Gum config selection"
  config=$choice
fi

validate_csv "$components_csv" components zsh yazi
validate_csv "$optional_csv" optional-tools shellcheck git-lfs glow viu act pandoc-cli
if [[ $node_manager == fnm && -z $fnm_node ]]; then
  die "fnm selection requires --fnm-node"
fi

if [[ $node_manager == fnm && $mise_active == true ]]; then
  die "fnm is mutually exclusive with active Mise Node at $mise_node_path; separately back up Mise config, run mise unuse --global node@VERSION --no-prune after approval, open a fresh shell, verify mise where node fails, then rerun"
fi
if [[ $node_manager == mise && $fnm_present == true ]]; then
  die "Mise Node and fnm cannot be coinstalled; remove the existing fnm choice separately before rerunning"
fi

declare -A selected=()
if [[ $components_csv != none ]]; then
  IFS=, read -r -a values <<< "$components_csv"
  for value in "${values[@]}"; do
    [[ $value == zsh ]] && selected[omarchy-zsh]=true
    [[ $value == yazi ]] && selected[yazi]=true
  done
fi
if [[ $optional_csv != none ]]; then
  IFS=, read -r -a values <<< "$optional_csv"
  for value in "${values[@]}"; do selected[$value]=true; done
fi
[[ $node_manager == fnm ]] && selected[fnm]=true
base_owned=()
already_present=()
queued=()

for package in "${catalog[@]}"; do
  [[ ${selected[$package]:-false} == true ]] || continue
  if base_owns "$package"; then
    omarchy pkg present "$package" >/dev/null 2>&1 ||
      die "$package is Omarchy base-owned but missing; repair Omarchy instead"
    base_owned+=("$package")
  elif omarchy pkg present "$package" >/dev/null 2>&1; then
    already_present+=("$package")
  else
    queued+=("$package")
  fi
done

fnm_install_command=()
fnm_default_command=()
if [[ $node_manager == mise ]]; then
  if $mise_active; then
    node_plan="preserve Mise Node: $mise_node_path"
    node_command=()
  else
    node_plan='install Mise Node with: omarchy install dev-env node'
    node_command=(omarchy install dev-env node)
  fi
else
  node_plan="install if absent: fnm install $fnm_node; set default if different: fnm default $fnm_node"
  node_command=()
  fnm_install_command=(fnm install "$fnm_node")
  fnm_default_command=(fnm default "$fnm_node")
fi

zsh_enabled=false
yazi_enabled=false
[[ ,$components_csv, == *,zsh,* ]] && zsh_enabled=true
[[ ,$components_csv, == *,yazi,* ]] && yazi_enabled=true
ansible_command=(ansible-playbook "$repo/setup.yml" --tags omarchy_config \
  -e "backup_dir=$backup_dir" -e "omarchy_zsh_enabled=$zsh_enabled" \
  -e "omarchy_yazi_enabled=$yazi_enabled")

join_or_none() {
  if (($#)); then
    printf '%s' "$*"
  else
    printf '%s' none
  fi
}
print_command() { printf '%q ' "$@"; printf '\n'; }
printf 'Target: %s\n' "$omarchy_path"
printf 'Base manifest: %s\n' "$base_manifest"
printf 'components: %s\n' "$components_csv"
printf 'optional-tools: %s\n' "$optional_csv"
printf 'node-manager: %s\n' "$node_manager"
printf 'Mise Node: %s\n' "$mise_node_path"
printf 'base-owned: %s\n' "$(join_or_none "${base_owned[@]}")"
printf 'already-present: %s\n' "$(join_or_none "${already_present[@]}")"
printf 'package-add: %s\n' "$(join_or_none "${queued[@]}")"
printf 'Node action: %s\n' "$node_plan"
printf 'config: %s (zsh=%s yazi=%s)\n' "$config" "$zsh_enabled" "$yazi_enabled"
printf 'receipt: %s\n' "$receipt"
if [[ $config == yes ]]; then
  printf 'Ansible command: '
  if $dry_run; then
    print_command "${ansible_command[@]}" --check --diff
  else
    print_command "${ansible_command[@]}"
  fi
else
  printf 'Ansible command: none\n'
fi
printf 'Rollback: restore only the five documented config paths; package/Node rollback is not provided.\n'

write_receipt_header() {
  printf 'repository-head: %s\n' "$(git -C "$repo" rev-parse HEAD)"
  printf 'date: %s\n' "$(date -Iseconds)"
  printf 'components: %s\n' "$components_csv"
  printf 'optional-tools: %s\n' "$optional_csv"
  printf 'base-owned: %s\n' "$(join_or_none "${base_owned[@]}")"
  printf 'already-present: %s\n' "$(join_or_none "${already_present[@]}")"
  printf 'queued: %s\n' "$(join_or_none "${queued[@]}")"
  printf 'node-manager: %s\n' "$node_manager"
  printf 'detected-mise-node: %s\n' "$mise_node_path"
  printf 'node-plan: %s\n' "$node_plan"
  printf 'ansible: tag=omarchy_config zsh=%s yazi=%s\n' "$zsh_enabled" "$yazi_enabled"
}

if $dry_run; then
  printf '%s\n' '--- dry-run receipt (not written) ---'
  write_receipt_header
  if ((${#queued[@]})); then
    printf 'command: '; print_command omarchy pkg add "${queued[@]}"; printf 'status: not-run\n'
  fi
  if ((${#node_command[@]})); then
    printf 'command: '; print_command "${node_command[@]}"; printf 'status: not-run\n'
  fi
  if [[ $node_manager == fnm ]]; then
    printf 'command (if absent): '; print_command "${fnm_install_command[@]}"; printf 'status: not-run\n'
    printf 'command (if default differs): '; print_command "${fnm_default_command[@]}"; printf 'status: not-run\n'
  fi
  if [[ $config == yes ]]; then
    printf 'command: '; print_command "${ansible_command[@]}" --check --diff; printf 'status: not-run\n'
  fi
  exit 0
fi

if ! $non_interactive; then
  "$gum" confirm --default=false 'Apply this plan?' || die "final confirmation cancelled"
fi

mkdir -p "$backup_dir"
write_receipt_header > "$receipt"
run_recorded() {
  printf 'command:' >> "$receipt"
  printf ' %q' "$@" >> "$receipt"
  printf '\n' >> "$receipt"
  set +e
  "$@"
  status=$?
  set -e
  printf 'status: %s\n' "$status" >> "$receipt"
  return "$status"
}

if ((${#queued[@]})); then
  run_recorded omarchy pkg add "${queued[@]}" || die "package installation failed; see $receipt"
fi

if [[ $node_manager == mise && ${#node_command[@]} -gt 0 ]]; then
  run_recorded "${node_command[@]}" || die "Mise Node installation failed; see $receipt"
elif [[ $node_manager == fnm ]]; then
  command -v fnm >/dev/null || die "fnm package installed but command is unavailable"
  escaped_fnm_node=${fnm_node//./\\.}
  fnm_version_pattern="(^|[[:space:]*])v?${escaped_fnm_node}([.][0-9]+)*([[:space:]]|$)"
  if ! fnm ls 2>/dev/null | grep -Eq "$fnm_version_pattern"; then
    run_recorded fnm install "$fnm_node" || die "fnm Node installation failed; see $receipt"
  fi
  current_default=$(fnm default 2>/dev/null || true)
  if ! grep -Eq "$fnm_version_pattern" <<< "$current_default"; then
    run_recorded fnm default "$fnm_node" || die "fnm default selection failed; see $receipt"
  fi
fi

if [[ $config == yes ]]; then
  run_recorded "${ansible_command[@]}" || die "configuration failed; see $receipt"
fi
printf 'Install complete. Receipt: %s\n' "$receipt"
