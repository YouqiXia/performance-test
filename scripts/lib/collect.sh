# collect.sh — result collection for uarch CLI
# Exposes: collect_results <test_list>
# Reads: CFG_BINDIR, CFG_LOGDIR, CFG_OUTPUT
# Writes: $CFG_LOGDIR/results.csv, $CFG_LOGDIR/summary.txt

collect_results() {
    local tests="$1"

    # Use existing SUMMARY_FILE if set by caller (preserves header),
    # otherwise create a new one
    SUMMARY_FILE="${SUMMARY_FILE:-$CFG_LOGDIR/summary.txt}"
    [[ -f "$SUMMARY_FILE" ]] || > "$SUMMARY_FILE"

    # CSV header
    local csvfile="$CFG_LOGDIR/results.csv"
    echo "test,variant,cycles_per_iter,insn_per_iter,ipc,cycles,instret,total_iters,instr_per_iter" > "$csvfile"

    local pass=0 fail_count=0 skip=0 fail_list=""

    while IFS= read -r test; do
        [[ -z "$test" ]] && continue
        local name="${test#$CFG_BINDIR/}"
        local logfile="$CFG_LOGDIR/${name}.log"

        if [[ ! -f "$logfile" ]]; then
            fail_count=$((fail_count+1))
            fail_list="${fail_list}  MISSING: $name (no log)\n"
            log "  [MISSING] $name"
            continue
        fi

        local rc
        rc=$(grep '^# Exit:' "$logfile" | head -1 | awk '{print $3}')
        rc="${rc:-1}"

        if [[ "$rc" -eq 0 ]]; then
            pass=$((pass+1))
            local perf_lines
            perf_lines=$(grep '^\s*\[' "$logfile" | grep -v '^\[perf\]' || true)
            if [[ -n "$perf_lines" ]]; then
                while IFS= read -r line; do
                    log "  $name ::$line"
                done <<< "$perf_lines"
            else
                log "  [PASS] $name"
            fi
            # Extract ##PERF## markers → CSV
            grep '^##PERF##' "$logfile" | while IFS= read -r marker; do
                local data="${marker#\#\#PERF\#\#|}"
                data="${data%\#\#}"
                echo "$name,${data//|/,}" >> "$csvfile"
            done
        elif [[ "$rc" -eq 124 ]]; then
            skip=$((skip+1))
            log "  [TIMEOUT] $name"
            fail_list="${fail_list}  TIMEOUT: $name\n"
        else
            fail_count=$((fail_count+1))
            if grep -q "illegal instruction" "$logfile"; then
                log "  [ILLEGAL] $name"
                fail_list="${fail_list}  ILLEGAL: $name (see $logfile)\n"
            else
                log "  [FAIL rc=$rc] $name"
                fail_list="${fail_list}  FAIL($rc): $name (see $logfile)\n"
            fi
        fi
    done <<< "$tests"

    # Summary
    local csv_rows total pct
    csv_rows=$(($(wc -l < "$csvfile") - 1))
    total=$((pass+fail_count+skip))
    pct=0
    [[ $total -gt 0 ]] && pct=$((pass * 100 / total))

    log ""
    log "========================================"
    log "  PASS: $pass / $total  ($pct%)"
    log "  FAIL: $fail_count"
    log "  SKIP: $skip (timeout)"
    log "  CSV:  $csvfile ($csv_rows entries)"
    log "  Logs: $CFG_LOGDIR/"
    log "========================================"

    if [[ -n "$fail_list" ]]; then
        log ""
        log "Failures:"
        log "$(echo -e "$fail_list")"
    fi

    # Copy summary to output if specified
    if [[ -n "$CFG_OUTPUT" ]]; then
        mkdir -p "$(dirname "$CFG_OUTPUT")"
        cp "$SUMMARY_FILE" "$CFG_OUTPUT"
        echo "(Summary also saved to $CFG_OUTPUT)"
    fi

    # Return exit code
    [[ $fail_count -eq 0 ]] && return 0 || return 1
}
