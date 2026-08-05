#!/bin/bash
# run_model_docker.sh — Run a single ELF through default BE model inside Docker
# Usage: run_model_docker.sh <elf_path>
#
# This script is meant to be called by "uarch run" via a config JSON.
# The ELF path can be relative (to performance_test root) or absolute.

set -uo pipefail

ELF="$1"

# Resolve to absolute path if relative
if [[ "$ELF" != /* ]]; then
    ELF="$(cd "$(dirname "$ELF")" && pwd)/$(basename "$ELF")"
fi

# Paths on the host
MODEL_DIR="/work/home/uatu/rawmodel/model"
PERF_DIR="/work/home/uatu/code/performance_test"

# Paths inside Docker (matching host mounts for simplicity)
DOCKER_MODEL_DIR="/work/home/uatu/workspace/model"
DOCKER_PERF_DIR="/work/home/uatu/code/performance_test"

# Map host ELF path to Docker ELF path
DOCKER_ELF="${ELF/#$PERF_DIR/$DOCKER_PERF_DIR}"

# PK path inside Docker
DOCKER_PK="$DOCKER_PERF_DIR/install/pk/pk"

exec docker run --rm \
    -v "$MODEL_DIR":"$DOCKER_MODEL_DIR" \
    -v "$PERF_DIR":"$DOCKER_PERF_DIR" \
    -w "$DOCKER_MODEL_DIR/release" \
    -e LD_LIBRARY_PATH="$DOCKER_MODEL_DIR/release/thirdparty/DRAMsim3:$DOCKER_MODEL_DIR/release/thirdparty/riscv-isa-sim/lib:$DOCKER_MODEL_DIR/release/lib" \
    model-dev-uatu-gcc15 \
    ./model \
        --arch-search-dir ../arches \
        --config-search-dir .. \
        --conf ../arches/json/arch.json \
        --spike-params="$DOCKER_PK" \
        "$DOCKER_ELF"
