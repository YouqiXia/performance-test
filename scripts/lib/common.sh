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

# ── Environment ──────────────────────────────────────────────────
# Load env file (pure KEY=VALUE, compatible with Makefile -include)
_uarch_env="${UARCH_ENV:-default}"
_env_file="$PROJECT_DIR/env/${_uarch_env}.env"
if [[ -f "$_env_file" ]]; then
    source "$_env_file"
else
    warn "env file not found: $_env_file (using defaults)"
fi

# ── Toolchain paths (derived from env) ───────────────────────────
RISCV_TOOLCHAIN="${RISCV_TOOLCHAIN:-/opt/riscv}"
MARCH="${MARCH:-rv64gc}"
ARCH="${ARCH:-default}"
RISCV_ELF_TOOLCHAIN="${RISCV_ELF_TOOLCHAIN:-$RISCV_TOOLCHAIN}"
LINUX_CC="$RISCV_TOOLCHAIN/bin/riscv64-unknown-linux-gnu-gcc"
ELF_CC="$RISCV_ELF_TOOLCHAIN/bin/riscv64-unknown-elf-gcc"

# ── install/ paths (populated by uarch build thirdparty) ─────────
SPIKE_BIN="$PROJECT_DIR/install/riscv-isa-sim/bin/spike"
SPIKE_PK="$PROJECT_DIR/install/pk/pk"
