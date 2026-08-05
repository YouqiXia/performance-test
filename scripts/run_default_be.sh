#!/bin/bash
# run_default_be.sh — Run a single ELF through default BE model inside Docker
set -uo pipefail

ELF="$1"

# Resolve to absolute path
[[ "$ELF" != /* ]] && ELF="$(cd "$(dirname "$ELF")" && pwd)/$(basename "$ELF")"

MODEL_DIR="/work/home/uatu/rawmodel/model"
PERF_DIR="/work/home/uatu/code/performance_test"
DOCKER_MODEL="/work/home/uatu/workspace/model"
SPIKE_ISA="rv64gcv_zba_zbb_zbs_zfh_zfhmin_zfa_zicond_zcb_zicboz_zicbom_zicbop_zicntr_zicsr_zifencei_zimop_zkt_zvbb_zvfhmin_zvkt_zihintpause_zihintntl"
PK="$PERF_DIR/install/pk/pk"

docker run --rm \
    -v "$MODEL_DIR":"$DOCKER_MODEL" \
    -v "$PERF_DIR":"$PERF_DIR" \
    -w "$DOCKER_MODEL/release" \
    -e LD_LIBRARY_PATH="$DOCKER_MODEL/release/thirdparty/DRAMsim3:$DOCKER_MODEL/release/thirdparty/riscv-isa-sim/lib:$DOCKER_MODEL/release/lib" \
    model-dev-uatu-gcc15 \
    ./model --arch-search-dir ../arches --config-search-dir .. \
        --conf ../arches/json/arch.json \
        --spike-params="-p1 --hartids=0 --isa=$SPIKE_ISA --priv=msu $PK" \
        "$ELF"
