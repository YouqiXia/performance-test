# discover.sh — test discovery for uarch CLI
# Exposes: discover_tests
# Reads: CFG_BINDIR, CFG_INCLUDE, CFG_EXCLUDE
# Output: test paths on stdout (one per line)

discover_tests() {
    local tests=""

    if [[ -n "$CFG_INCLUDE" ]]; then
        while IFS= read -r dir; do
            [[ -z "$dir" ]] && continue
            local target="$CFG_BINDIR/$dir"
            if [[ -d "$target" ]]; then
                local found
                found=$(find "$target" -type f -executable | sort)
                tests="${tests}${tests:+$'\n'}${found}"
            elif [[ -x "$target" ]]; then
                tests="${tests}${tests:+$'\n'}${target}"
            else
                echo "Warning: include path '$dir' not found in $CFG_BINDIR, skipping" >&2
            fi
        done <<< "$CFG_INCLUDE"
        tests=$(echo "$tests" | sort -u)
    else
        tests=$(find "$CFG_BINDIR" -type f -executable | sort)
    fi

    # Apply excludes
    if [[ -n "$CFG_EXCLUDE" ]]; then
        while IFS= read -r pat; do
            [[ -z "$pat" ]] && continue
            tests=$(echo "$tests" | grep -v "$pat" || true)
        done <<< "$CFG_EXCLUDE"
    fi

    local count
    count=$(echo "$tests" | grep -c . || echo 0)
    if [[ "$count" -eq 0 ]]; then
        die "No tests found (bindir=$CFG_BINDIR)"
    fi

    echo "$tests"
}
