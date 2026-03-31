# common.sh — shared library for uarch CLI
# Usage: source "$(dirname "$0")/lib/common.sh"

set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$(cd "$SCRIPTS_DIR/.." && pwd)"

# ── Colors ────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    GREEN='\033[32m' RED='\033[31m' YELLOW='\033[33m'
    CYAN='\033[36m' BOLD='\033[1m' DIM='\033[2m' RESET='\033[0m'
else
    GREEN='' RED='' YELLOW='' CYAN='' BOLD='' DIM='' RESET=''
fi

# ── Output helpers ────────────────────────────────────────────────
log()  { echo "$@" | tee -a "${SUMMARY_FILE:-/dev/null}"; }
ok()   { printf "  ${GREEN}✔${RESET} %s\n" "$*"; }
fail() { printf "  ${RED}✗${RESET} %s\n" "$*"; }
warn() { printf "  ${YELLOW}●${RESET} %s\n" "$*"; }
die()  { echo "Error: $*" >&2; exit 2; }

# ── Path helpers ──────────────────────────────────────────────────
# Resolve ~ in a string (for JSON config values)
expand_home() { echo "${1/#\~/$HOME}"; }
