#!/usr/bin/env bash
# Generate checkpoints for all ELFs in bin_spike_ckpt/
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

SPIKE="${PROJECT_DIR}/thirdparty/riscv-isa-sim/install/bin/spike"
PK="${HOME}/workspace/riscv-pk/build/pk"
ISA="--isa=rv64gcv_zba_zbb_zbs_zfh_zfhmin_zfa_zicond_zcb_zicboz_zicbom_zicbop_zicntr_zicsr_zifencei_zimop_zkt_zvbb_zvfhmin_zvkt_zihintpause_zihintntl"
CKPT_ELF_DIR="${PROJECT_DIR}/bin_spike_ckpt"
CKPT_OUT_DIR="${PROJECT_DIR}/checkpoints"
COMPRESS_FLAG="--compress-zstd"
MEM=64
JOBS=8

# Allow overrides
SPIKE="${SPIKE_BIN:-$SPIKE}"
PK="${SPIKE_PK:-$PK}"
JOBS="${CKPT_JOBS:-$JOBS}"
MEM="${CKPT_MEM:-$MEM}"

if [[ ! -x "$SPIKE" ]]; then
    echo "ERROR: spike not found at $SPIKE" >&2
    exit 1
fi
if [[ ! -f "$PK" ]]; then
    echo "ERROR: pk not found at $PK" >&2
    exit 1
fi

TOTAL=$(find "$CKPT_ELF_DIR" -type f -executable | wc -l)
echo "=== Batch checkpoint: $TOTAL ELFs (${JOBS} parallel, -m${MEM}) ==="
echo "  spike: $SPIKE"
echo "  pk:    $PK"
echo "  input: $CKPT_ELF_DIR"
echo "  output: $CKPT_OUT_DIR"
echo "  compress: $COMPRESS_FLAG"
echo ""

export SPIKE PK ISA COMPRESS_FLAG CKPT_ELF_DIR CKPT_OUT_DIR MEM

run_one() {
    local elf="$1"
    local rel="${elf#$CKPT_ELF_DIR/}"
    local ckpt_name="${rel##*/}"
    local ckpt_dir="${CKPT_OUT_DIR}/${rel%/*}"
    local ckpt_path="${ckpt_dir}/${ckpt_name}"

    mkdir -p "$ckpt_dir"

    # Skip if checkpoint already exists
    if [[ -f "${ckpt_path}.bootram" ]]; then
        echo "SKIP  $rel"
        return
    fi

    if $SPIKE $ISA -m"$MEM" $COMPRESS_FLAG --save="$ckpt_path" "$PK" "$elf" \
        </dev/null >/dev/null 2>"${ckpt_path}.log"; then
        if [[ -f "${ckpt_path}.bootram" ]]; then
            rm -f "${ckpt_path}.log"
            echo "OK  $rel"
        else
            echo "FAIL(no output)  $rel"
        fi
    else
        echo "FAIL  $rel  (see ${ckpt_path}.log)"
    fi
}
export -f run_one

find "$CKPT_ELF_DIR" -type f -executable | sort | \
    xargs -P "$JOBS" -I{} bash -c 'run_one "$@"' _ {} | \
    tee /dev/stderr | {
    OK=0; FAIL=0; SKIP=0; FAIL_LIST=""
    while IFS= read -r line; do
        if [[ "$line" == OK* ]]; then
            OK=$((OK+1))
        elif [[ "$line" == SKIP* ]]; then
            SKIP=$((SKIP+1))
        else
            FAIL=$((FAIL+1))
            FAIL_LIST="${FAIL_LIST}\n  ${line#*  }"
        fi
    done
    echo "" >&2
    echo "=== Done: $OK OK, $SKIP SKIP, $FAIL FAIL (total $TOTAL) ===" >&2
    if [[ $FAIL -gt 0 ]]; then
        echo "Failed:" >&2
        echo -e "$FAIL_LIST" >&2
        exit 1
    fi
}
