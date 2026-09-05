# Helpers sourced by install.sh and every install/<step>.sh. No shebang, no set -e.

C_INFO=$'\e[36m'; C_OK=$'\e[32m'; C_WARN=$'\e[33m'; C_ERR=$'\e[31m'; C_OFF=$'\e[0m'

banner() {
  echo
  echo "${C_INFO}  MausOS installer${C_OFF}"
  echo "  structure before pixels · every app is callable"
  echo
}

log_line() { printf '%s\t%s\n' "$(date -Is)" "$*" >> "$MAUSOS_LOG" 2>/dev/null || true; }
info() { echo "${C_INFO}::${C_OFF} $*"; log_line "info $*"; }
ok()   { echo "${C_OK}✓${C_OFF} $*"; log_line "ok $*"; }
warn() { echo "${C_WARN}!${C_OFF} $*" >&2; log_line "warn $*"; }
die()  { echo "${C_ERR}✗${C_OFF} $*" >&2; log_line "die $*"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }

step_skipped() {
  local step=$1
  [[ " ${MAUSOS_SKIP:-} " == *" $step "* ]]
}

run_step() {
  local step=$1
  local file="$MAUSOS_INSTALL/$step.sh"
  [[ -f "$file" ]] || die "no such install step: $step"
  echo
  echo "${C_INFO}── $step ──${C_OFF}"
  log_line "step $step start"
  # shellcheck source=/dev/null
  source "$file"
  log_line "step $step done"
}

# Install packages through the most specific tool available.
#   Omarchy 4 blocks direct pacman unless OMARCHY_ALLOW_DIRECT_PACMAN=1,
#   so prefer `omarchy pkg add`, then yay (AUR-capable), then pacman.
pkg_add() {
  local missing=()
  local p
  for p in "$@"; do
    pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
  done
  [[ ${#missing[@]} -eq 0 ]] && return 0
  info "installing: ${missing[*]}"
  if have omarchy-pkg-add; then
    omarchy-pkg-add "${missing[@]}"
  elif have omarchy; then
    omarchy pkg add "${missing[@]}"
  elif have yay; then
    yay -S --needed --noconfirm "${missing[@]}"
  else
    sudo pacman -S --needed --noconfirm "${missing[@]}"
  fi
}

# Append a line to a file if it is not already there (exact match).
ensure_line() {
  local file=$1 line=$2
  mkdir -p "$(dirname "$file")"
  touch "$file"
  grep -qxF -- "$line" "$file" || printf '%s\n' "$line" >> "$file"
}

# Create or replace a symlink, never clobbering a real file.
link_into() {
  local target=$1 link=$2
  mkdir -p "$(dirname "$link")"
  if [[ -e "$link" && ! -L "$link" ]]; then
    warn "not replacing real file $link"
    return 0
  fi
  ln -sfn "$target" "$link"
}

in_hyprland() { [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && have hyprctl; }

# Wait for mausd to answer on loopback.
wait_for_mausd() {
  local tries=${1:-30}
  local url="http://127.0.0.1:${OMB_PORT:-8799}/api/health"
  local i
  for ((i = 0; i < tries; i++)); do
    if curl -fsS --max-time 2 "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}
