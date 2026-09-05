# Shared helpers for every maus-* command. Sourced, never executed.
#
# Commands are symlinked into ~/.local/bin, so they resolve this file through
# the real path of the script:
#   source "$(dirname "$(readlink -f "$0")")/../lib/maus-common.sh"

MAUS_DIR="${MAUS_DIR:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"
MAUS_BIN_DIR="$MAUS_DIR/bin"
MAUS_LIB_DIR="$MAUS_DIR/lib"
MAUS_REGISTRY_DIR="${MAUS_REGISTRY_DIR:-$MAUS_DIR/registry/manifests}"
MAUS_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}/mausos"
MAUS_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/mausos"
MAUS_DATA_DIR="${MAUSOS_DATA:-$HOME/.local/share/mausos}"
MAUSD_URL="${MAUSD_URL:-http://127.0.0.1:${OMB_PORT:-8799}}"
MAUS_COMMAND="${MAUS_COMMAND:-$(basename "$0")}"
export MAUS_DIR MAUS_BIN_DIR MAUS_LIB_DIR MAUS_REGISTRY_DIR MAUS_RUNTIME_DIR MAUS_STATE_DIR MAUS_DATA_DIR MAUSD_URL

maus_die() {
  echo "$MAUS_COMMAND: $*" >&2
  exit 1
}

maus_warn() {
  echo "$MAUS_COMMAND: $*" >&2
}

# Fail early with a useful message when a dependency is missing.
maus_need() {
  local c
  for c in "$@"; do
    command -v "$c" >/dev/null 2>&1 || maus_die "missing command: $c (run: maus doctor)"
  done
}

maus_have() { command -v "$1" >/dev/null 2>&1; }

# True when --json appears among the arguments.
maus_want_json() {
  local a
  for a in "$@"; do [[ $a == "--json" ]] && return 0; done
  return 1
}

# Drop --json from "$@" and print the rest, one per line (use with mapfile).
maus_strip_json() {
  local a
  for a in "$@"; do [[ $a == "--json" ]] || printf '%s\n' "$a"; done
}

# Minimal JSON string escaping for bash-built JSON.
maus_json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

# Append a line to the action log. Every command that changes the desktop
# calls this so "what did the agent do" has an answer.
maus_log() {
  mkdir -p "$MAUS_STATE_DIR"
  printf '%s\t%s\t%s\n' "$(date -Is)" "$MAUS_COMMAND" "$*" >> "$MAUS_STATE_DIR/actions.log"
}

# Run the AT-SPI tool.
maus_atspi() {
  maus_need python3
  python3 "$MAUS_LIB_DIR/atspi.py" "$@"
}

# hyprctl with JSON, or a clear error outside Hyprland.
maus_hypr() {
  maus_need hyprctl
  [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] || maus_die "not inside a Hyprland session"
  hyprctl "$@"
}

# curl against mausd on loopback.
maus_api() {
  maus_need curl
  local method=$1 path=$2 body=${3:-}
  if [[ -n $body ]]; then
    curl -fsS --max-time 20 -X "$method" -H 'Content-Type: application/json' \
      --data "$body" "$MAUSD_URL$path"
  else
    curl -fsS --max-time 20 -X "$method" "$MAUSD_URL$path"
  fi
}

# Print usage from the command's own header (the maus:summary / maus:args lines).
maus_usage() {
  local file
  file=$(readlink -f "$0")
  local summary args
  summary=$(sed -n 's/^# maus:summary=//p' "$file" | head -1)
  args=$(sed -n 's/^# maus:args=//p' "$file" | head -1)
  echo "$MAUS_COMMAND $args"
  echo "  $summary"
  local ex
  ex=$(sed -n 's/^# maus:examples=//p' "$file" | head -1)
  if [[ -n $ex ]]; then
    echo "examples:"
    tr '|' '\n' <<< "$ex" | sed 's/^/  /'
  fi
}

# Handle -h/--help uniformly.
maus_help_if_asked() {
  local a
  for a in "$@"; do
    if [[ $a == "-h" || $a == "--help" ]]; then
      maus_usage
      exit 0
    fi
  done
}
