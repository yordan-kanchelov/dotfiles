#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
cd "$repo"

die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
usage() {
  cat <<'EOF'
Usage: ./install-omarchy.sh [options]

  --components bash,yazi|bash|yazi|none
  --optional-tools shellcheck,git-lfs,glow,viu|none
  --config yes|no
  --backup-dir ABSOLUTE_PATH
  --non-interactive
  --yes
  --dry-run
  --help
EOF
}

components_csv=bash,yazi
optional_csv=shellcheck
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
    --components|--optional-tools|--config|--backup-dir)
      (($# >= 2)) || die "$1 requires a value"
      value=$2
      case $1 in
        --components) set_option components_csv "$value" ;;
        --optional-tools) set_option optional_csv "$value" ;;

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

validate_csv "$components_csv" components bash yazi
validate_csv "$optional_csv" optional-tools shellcheck git-lfs glow viu
[[ $config == yes || $config == no ]] || die "config must be yes or no"
if $non_interactive && ! $dry_run && ! $assume_yes; then
  die "mutating --non-interactive runs require --yes"
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

safe_directories() {
  local path=$1
  [[ $path == /* ]] || die 'HOME and backup directories must be absolute'
  while [[ -n $path && $path != / ]]; do
    [[ ! -L $path ]] || die "symlinked directory refused: $path"
    [[ ! -e $path || -d $path ]] || die "non-directory ancestor: $path"
    path=${path%/*}
  done
}
safe_directories "$HOME/.dotfiles_backup"
backup_root=$(realpath -m "$HOME/.dotfiles_backup")
if [[ -z $backup_dir ]]; then
  backup_dir="$backup_root/omarchy-$(date +%Y%m%d-%H%M%S)"
fi
[[ $backup_dir == /* ]] || die "--backup-dir must be absolute"
safe_directories "$backup_dir"
backup_dir=$(realpath -m "$backup_dir")
[[ $backup_dir == "$backup_root"/* ]] || die "--backup-dir must be beneath $backup_root"
receipt="$backup_dir/omarchy-install.receipt"
[[ ! -e $receipt && ! -L $receipt ]] || die 'receipt already exists; choose a fresh backup directory'

catalog=(yazi shellcheck git-lfs glow viu)
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
  printf 'Runtime: KEEP (no detection, provisioning or switching)\n'
  for target in .bashrc .config/dotfiles/bash/personal.bash .config/dotfiles/shell/aliases.sh; do
    if [[ -e $HOME/$target || -L $HOME/$target ]]; then
      state=present
    else
      state=absent
    fi
    printf 'Config target %-43s %s\n' "$HOME/$target" "$state"
  done

  if ! choice=$("$gum" choose --no-limit --header 'Core defaults' --selected 'Bash shortcuts + vi' --selected Yazi \
    'Bash shortcuts + vi' Yazi); then
    die "component selection cancelled"
  fi
  components_csv=none
  if grep -Fxq 'Bash shortcuts + vi' <<< "$choice"; then
    components_csv=bash
  fi
  if grep -Fxq Yazi <<< "$choice"; then
    if [[ $components_csv == none ]]; then
      components_csv=yazi
    else
      components_csv+=,yazi
    fi
  fi

  if ! choice=$("$gum" choose --no-limit --header 'Optional tools' --selected ShellCheck \
    ShellCheck git-lfs glow viu); then
    die "optional-tool selection cancelled"
  fi
  optional_csv=none
  for label in ShellCheck git-lfs glow viu; do
    if grep -Fxq "$label" <<< "$choice"; then
      package=${label/ShellCheck/shellcheck}
      if [[ $optional_csv == none ]]; then
        optional_csv=$package
      else
        optional_csv+=,$package
      fi
    fi
  done


  if ! choice=$("$gum" choose --header 'Apply selected configuration?' --selected yes yes no); then
    die "configuration selection cancelled"
  fi
  [[ $choice == yes || $choice == no ]] || die "invalid Gum config selection"
  config=$choice
fi

validate_csv "$components_csv" components bash yazi
validate_csv "$optional_csv" optional-tools shellcheck git-lfs glow viu

declare -A selected=()
if [[ $components_csv != none ]]; then
  IFS=, read -r -a values <<< "$components_csv"
  for value in "${values[@]}"; do

    [[ $value == yazi ]] && selected[yazi]=true
  done
fi
if [[ $optional_csv != none ]]; then
  IFS=, read -r -a values <<< "$optional_csv"
  for value in "${values[@]}"; do selected[$value]=true; done
fi

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

bash_enabled=false
yazi_enabled=false
[[ ,$components_csv, == *,bash,* ]] && bash_enabled=true
[[ ,$components_csv, == *,yazi,* ]] && yazi_enabled=true
ansible_command=(ansible-playbook "$repo/setup.yml" --tags omarchy_config \
  -e "backup_dir=$backup_dir" -e "omarchy_bash_enabled=$bash_enabled" \
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
printf 'Runtime: KEEP (no detection, provisioning or switching)\n'
printf 'base-owned: %s\n' "$(join_or_none "${base_owned[@]}")"
printf 'already-present: %s\n' "$(join_or_none "${already_present[@]}")"
printf 'package-add: %s\n' "$(join_or_none "${queued[@]}")"
printf 'config: %s (bash=%s yazi=%s)\n' "$config" "$bash_enabled" "$yazi_enabled"
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
printf 'Bash: selected personal shortcuts + native vi; activates in a new shell.\n'
printf 'ls overrides output with eza; tk/tkill destroy sessions when invoked; tkp/:q exit.\n'
printf 'Keep official c, cat, clear; omit cleaners and private agent wrappers.\n'
printf 'Yazi: package only; y wrapper comes with Bash. Existing appearance and runtime stay unchanged.\n'
printf 'Tools: shellcheck checks scripts; glow reads Markdown; viu views images; git-lfs stores large Git assets.\n'
printf 'Rollback: only recorded Bash block/sidecars, never application configs or packages. See README.\n'

write_receipt_header() {
  printf 'repository-head: %s\n' "$(git -C "$repo" rev-parse HEAD)"
  printf 'date: %s\n' "$(date -Iseconds)"
  printf 'components: %s\n' "$components_csv"
  printf 'optional-tools: %s\n' "$optional_csv"
  printf 'base-owned: %s\n' "$(join_or_none "${base_owned[@]}")"
  printf 'already-present: %s\n' "$(join_or_none "${already_present[@]}")"
  printf 'queued: %s\n' "$(join_or_none "${queued[@]}")"
  printf 'runtime: KEEP\n'
  printf 'ansible: tag=omarchy_config bash=%s yazi=%s\n' "$bash_enabled" "$yazi_enabled"
}

if $dry_run; then
  printf '%s\n' '--- dry-run receipt (not written) ---'
  write_receipt_header
  if ((${#queued[@]})); then
    printf 'command: '; print_command omarchy pkg add "${queued[@]}"; printf 'status: not-run\n'
  fi

  if [[ $config == yes ]]; then
    printf 'command: '; print_command "${ansible_command[@]}" --check --diff; printf 'status: not-run\n'
  fi
  exit 0
fi

if ! $non_interactive; then
  "$gum" confirm --default=false 'Apply this plan?' || die "final confirmation cancelled"
fi

umask 077
mkdir -p "$backup_dir"
write_receipt_header > "$receipt"
run_recorded() {
  {
    printf 'command:'
    printf ' %q' "$@"
    printf '\n'
  } >> "$receipt"
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


if [[ $config == yes ]]; then
  run_recorded "${ansible_command[@]}" || die "configuration failed; see $receipt"
fi
printf 'Install complete. Receipt: %s\n' "$receipt"
