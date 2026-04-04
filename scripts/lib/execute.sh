# execute.sh — test execution for uarch CLI
# Exposes: execute_tests <test_list>
# Reads: CFG_COMMAND, CFG_LOGDIR, CFG_TIMEOUT, CFG_JOBS, CFG_BINDIR

execute_tests() {
    local tests="$1"
    mkdir -p "$CFG_LOGDIR"

    # Generate run_one helper script
    local run_one="$CFG_LOGDIR/.run_one.sh"
    cat > "$run_one" << 'RUNONE_EOF'
#!/bin/bash
set -uo pipefail
test="$1"
name="${test#$RUN_BINDIR/}"
logfile="$RUN_LOGDIR/${name}.log"
mkdir -p "$(dirname "$logfile")"

# Second-stage template resolution (per-test variables)
real_cmd="$RUN_COMMAND"
if echo "$real_cmd" | grep -q '{elf}'; then
    real_cmd="${real_cmd//\{elf\}/./$test}"
else
    real_cmd="$real_cmd ./$test"
fi
# {checkpoint}: derive from elf path — bin/checkpoint/X/Y → checkpoints/X/Y/Y.bootram
if echo "$real_cmd" | grep -q '{checkpoint}'; then
    ckpt_rel="${test#$RUN_BINDIR/}"
    ckpt_name="${ckpt_rel##*/}"
    ckpt_path="checkpoints/${ckpt_rel%/*}/${ckpt_name}.bootram"
    real_cmd="${real_cmd//\{checkpoint\}/$ckpt_path}"
fi

test_output=$(timeout "$RUN_TIMEOUT" bash -c "$real_cmd" 2>&1) && rc=0 || rc=$?

{
    echo "# Test: $name"
    echo "# Exit: $rc"
    echo "# Time: $(date -Iseconds)"
    echo "---"
    echo "$test_output"
} > "$logfile"

if [ $rc -eq 0 ]; then
    echo "  [done] $name" >&2
elif [ $rc -eq 124 ]; then
    echo "  [time] $name" >&2
else
    echo "  [FAIL] $name" >&2
fi
RUNONE_EOF
    chmod +x "$run_one"

    # Export config as environment variables
    export RUN_BINDIR="$CFG_BINDIR"
    export RUN_LOGDIR="$CFG_LOGDIR"
    export RUN_COMMAND="$CFG_COMMAND"
    export RUN_TIMEOUT="$CFG_TIMEOUT"

    # Execute
    if [[ "$CFG_JOBS" -le 1 ]]; then
        while IFS= read -r test; do
            [[ -z "$test" ]] && continue
            bash "$run_one" "$test" || true
        done <<< "$tests"
    else
        echo "$tests" | xargs -P "$CFG_JOBS" -I {} bash "$run_one" {} || true
    fi

    # Cleanup
    rm -f "$run_one"
}
