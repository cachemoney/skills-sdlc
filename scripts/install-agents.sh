#!/usr/bin/env bash
# Install this repository's platform-specific agent definitions as individual links.
set -euo pipefail

REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_SOURCE_DIR="$REPOSITORY_ROOT/agents"
CODEX_SOURCE_DIR="$REPOSITORY_ROOT/.codex/agents"
PI_SOURCE_DIR="$REPOSITORY_ROOT/.pi/agent/agents"
ANTIGRAVITY_SOURCE_DIR="$REPOSITORY_ROOT/.antigravity/agents"
OPENCODE_SOURCE_DIR="$REPOSITORY_ROOT/.opencode/agents"
CLAUDE_INSTALL_DIR="${HOME}/.claude/agents"
CODEX_INSTALL_DIR="${HOME}/.codex/agents"
PI_INSTALL_DIR="${HOME}/.pi/agent/agents"
ANTIGRAVITY_INSTALL_DIR="${HOME}/.gemini/config/agents"
OPENCODE_INSTALL_DIR="${HOME}/.config/opencode/agents"
PI_HOME="${HOME}/.pi"
PI_INSTALL_DIR_EXPLICIT=false
ANTIGRAVITY_HOME="${HOME}/.gemini"
ANTIGRAVITY_INSTALL_DIR_EXPLICIT=false
OPENCODE_HOME="${HOME}/.config/opencode"
OPENCODE_INSTALL_DIR_EXPLICIT=false
FORCE=false
DRY_RUN=false

usage() {
  cat <<'EOF'
Usage: ./scripts/install-agents.sh [options]

Symlink this repository's Claude, Codex, Pi, Antigravity, and OpenCode agent
definitions into their respective user agent directories. Optional harnesses
(Pi, Antigravity, OpenCode) are only installed when their configuration
directories (~/.pi, ~/.gemini, ~/.config/opencode) already exist, unless their
install directories are given explicitly.

Options:
  --dry-run                    Print planned filesystem operations without changing anything.
  --force                      Back up conflicting destination entries, then install links.
  --claude-source-dir DIR      Override agents/.
  --codex-source-dir DIR       Override .codex/agents/.
  --pi-source-dir DIR          Override .pi/agent/agents/.
  --antigravity-source-dir DIR Override .antigravity/agents/.
  --opencode-source-dir DIR    Override .opencode/agents/.
  --claude-install-dir DIR     Override ~/.claude/agents/.
  --codex-install-dir DIR      Override ~/.codex/agents/.
  --pi-install-dir DIR         Override ~/.pi/agent/agents/ and force Pi installation.
  --antigravity-install-dir DIR Override ~/.gemini/config/agents/ and force Antigravity installation.
  --opencode-install-dir DIR   Override ~/.config/opencode/agents/ and force OpenCode installation.
  -h, --help                   Print this help text.
EOF
}

die() {
  echo "install-agents: $*" >&2
  exit 1
}

run() {
  if "$DRY_RUN"; then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=true ;;
    --force) FORCE=true ;;
    --claude-source-dir)
      [ "$#" -ge 2 ] || die '--claude-source-dir requires a directory'
      CLAUDE_SOURCE_DIR="$2"
      shift
      ;;
    --codex-source-dir)
      [ "$#" -ge 2 ] || die '--codex-source-dir requires a directory'
      CODEX_SOURCE_DIR="$2"
      shift
      ;;
    --pi-source-dir)
      [ "$#" -ge 2 ] || die '--pi-source-dir requires a directory'
      PI_SOURCE_DIR="$2"
      shift
      ;;
    --antigravity-source-dir)
      [ "$#" -ge 2 ] || die '--antigravity-source-dir requires a directory'
      ANTIGRAVITY_SOURCE_DIR="$2"
      shift
      ;;
    --opencode-source-dir)
      [ "$#" -ge 2 ] || die '--opencode-source-dir requires a directory'
      OPENCODE_SOURCE_DIR="$2"
      shift
      ;;
    --claude-install-dir)
      [ "$#" -ge 2 ] || die '--claude-install-dir requires a directory'
      CLAUDE_INSTALL_DIR="$2"
      shift
      ;;
    --codex-install-dir)
      [ "$#" -ge 2 ] || die '--codex-install-dir requires a directory'
      CODEX_INSTALL_DIR="$2"
      shift
      ;;
    --pi-install-dir)
      [ "$#" -ge 2 ] || die '--pi-install-dir requires a directory'
      PI_INSTALL_DIR="$2"
      PI_INSTALL_DIR_EXPLICIT=true
      shift
      ;;
    --antigravity-install-dir)
      [ "$#" -ge 2 ] || die '--antigravity-install-dir requires a directory'
      ANTIGRAVITY_INSTALL_DIR="$2"
      ANTIGRAVITY_INSTALL_DIR_EXPLICIT=true
      shift
      ;;
    --opencode-install-dir)
      [ "$#" -ge 2 ] || die '--opencode-install-dir requires a directory'
      OPENCODE_INSTALL_DIR="$2"
      OPENCODE_INSTALL_DIR_EXPLICIT=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

discover_agents() {
  local source_dir="$1" extensions="$2" platform="$3" candidate extension label
  local -n agents="$4"
  local -a extension_list=()

  [ -d "$source_dir" ] || die "$platform source directory does not exist: $source_dir"
  source_dir="$(cd "$source_dir" && pwd -P)"
  read -r -a extension_list <<<"$extensions"
  shopt -s nullglob
  for extension in "${extension_list[@]}"; do
    for candidate in "$source_dir"/*."$extension"; do
      [ -f "$candidate" ] && agents+=("$candidate")
    done
  done
  shopt -u nullglob
  if [ "${#agents[@]}" -eq 0 ]; then
    label=".${extension_list[0]}"
    for extension in "${extension_list[@]:1}"; do
      label+=", .$extension"
    done
    die "no $platform $label agent files found in: $source_dir"
  fi
}

preflight_target() {
  local source="$1" target="$2"

  if [ -e "$target" ] || [ -L "$target" ]; then
    [ "$target" -ef "$source" ] && return
    "$FORCE" || die "refusing to replace existing agent link: $target (rerun with --force)"
  fi
}

backup_path() {
  local target="$1" candidate suffix=1

  candidate="$target.backup.$(date +%Y%m%d%H%M%S)"
  while [ -e "$candidate" ] || [ -L "$candidate" ]; do
    candidate="$target.backup.$(date +%Y%m%d%H%M%S).$suffix"
    suffix=$((suffix + 1))
  done
  printf '%s\n' "$candidate"
}

install_agent() {
  local source="$1" destination="$2" target backup

  target="$destination/$(basename "$source")"
  if [ -e "$target" ] || [ -L "$target" ]; then
    [ "$target" -ef "$source" ] && return
    backup="$(backup_path "$target")"
    run mv "$target" "$backup"
    if "$DRY_RUN"; then
      echo "Would back up $target to $backup" >&2
    else
      echo "Backed up $target to $backup" >&2
    fi
  fi
  run ln -s "$source" "$target"
}

install_pi=false
if "$PI_INSTALL_DIR_EXPLICIT" || [ -d "$PI_HOME" ]; then
  install_pi=true
fi

install_antigravity=false
if "$ANTIGRAVITY_INSTALL_DIR_EXPLICIT" || [ -d "$ANTIGRAVITY_HOME" ]; then
  install_antigravity=true
fi

install_opencode=false
if "$OPENCODE_INSTALL_DIR_EXPLICIT" || [ -d "$OPENCODE_HOME" ]; then
  install_opencode=true
fi

declare -a claude_agents=()
declare -a codex_agents=()
declare -a pi_agents=()
declare -a antigravity_agents=()
declare -a opencode_agents=()

discover_agents "$CLAUDE_SOURCE_DIR" md Claude claude_agents
discover_agents "$CODEX_SOURCE_DIR" toml Codex codex_agents
if "$install_pi"; then
  discover_agents "$PI_SOURCE_DIR" 'md toml' Pi pi_agents
fi
if "$install_antigravity"; then
  discover_agents "$ANTIGRAVITY_SOURCE_DIR" md Antigravity antigravity_agents
fi
if "$install_opencode"; then
  discover_agents "$OPENCODE_SOURCE_DIR" md OpenCode opencode_agents
fi

for source in "${claude_agents[@]}"; do
  preflight_target "$source" "$CLAUDE_INSTALL_DIR/$(basename "$source")"
done
for source in "${codex_agents[@]}"; do
  preflight_target "$source" "$CODEX_INSTALL_DIR/$(basename "$source")"
done
if "$install_pi"; then
  for source in "${pi_agents[@]}"; do
    preflight_target "$source" "$PI_INSTALL_DIR/$(basename "$source")"
  done
fi
if "$install_antigravity"; then
  for source in "${antigravity_agents[@]}"; do
    preflight_target "$source" "$ANTIGRAVITY_INSTALL_DIR/$(basename "$source")"
  done
fi
if "$install_opencode"; then
  for source in "${opencode_agents[@]}"; do
    preflight_target "$source" "$OPENCODE_INSTALL_DIR/$(basename "$source")"
  done
fi

run mkdir -p "$CLAUDE_INSTALL_DIR"
run mkdir -p "$CODEX_INSTALL_DIR"
for source in "${claude_agents[@]}"; do
  install_agent "$source" "$CLAUDE_INSTALL_DIR"
done
for source in "${codex_agents[@]}"; do
  install_agent "$source" "$CODEX_INSTALL_DIR"
done

declare -a installed_dirs=("$CLAUDE_INSTALL_DIR" "$CODEX_INSTALL_DIR")
if "$install_pi"; then
  run mkdir -p "$PI_INSTALL_DIR"
  for source in "${pi_agents[@]}"; do
    install_agent "$source" "$PI_INSTALL_DIR"
  done
  installed_dirs+=("$PI_INSTALL_DIR")
else
  echo "Skipping Pi agents: $PI_HOME does not exist" >&2
fi

if "$install_antigravity"; then
  run mkdir -p "$ANTIGRAVITY_INSTALL_DIR"
  for source in "${antigravity_agents[@]}"; do
    install_agent "$source" "$ANTIGRAVITY_INSTALL_DIR"
  done
  installed_dirs+=("$ANTIGRAVITY_INSTALL_DIR")
else
  echo "Skipping Antigravity agents: $ANTIGRAVITY_HOME does not exist" >&2
fi

if "$install_opencode"; then
  run mkdir -p "$OPENCODE_INSTALL_DIR"
  for source in "${opencode_agents[@]}"; do
    install_agent "$source" "$OPENCODE_INSTALL_DIR"
  done
  installed_dirs+=("$OPENCODE_INSTALL_DIR")
else
  echo "Skipping OpenCode agents: $OPENCODE_HOME does not exist" >&2
fi

destinations="${installed_dirs[0]}"
for dir in "${installed_dirs[@]:1}"; do
  destinations+=" and $dir"
done
if "$DRY_RUN"; then
  echo "Dry run complete for $destinations"
else
  echo "Installed agent links in $destinations"
fi
