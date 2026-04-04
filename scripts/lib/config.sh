# config.sh — JSON config parser for uarch CLI
# Exposes: parse_config <file>
# Sets globals: CFG_COMMAND, CFG_BINDIR, CFG_JOBS, CFG_TIMEOUT,
#               CFG_INCLUDE, CFG_EXCLUDE, CFG_LOGDIR, CFG_OUTPUT

_read_json() {
    local config="$1" key="$2" default="${3:-}"
    python3 -c "
import json, os, sys
c = json.load(open('$config'))
val = c.get('$key', '$default')
if isinstance(val, str):
    val = os.path.expanduser(val)
if isinstance(val, list):
    print('\n'.join(str(v) for v in val))
else:
    print(val if val is not None else '$default')
"
}

parse_config() {
    local config="$1"
    [[ -f "$config" ]] || die "config file '$config' not found"

    CFG_COMMAND=$(_read_json "$config" command "")
    CFG_BINDIR=$(_read_json "$config" bindir "")
    CFG_JOBS=$(_read_json "$config" jobs "1")
    CFG_TIMEOUT_MIN=$(_read_json "$config" timeout "1")
    CFG_TIMEOUT=$((CFG_TIMEOUT_MIN * 60))
    CFG_OUTPUT=$(_read_json "$config" output "")
    CFG_LOGDIR=$(_read_json "$config" logdir "")
    CFG_INCLUDE=$(_read_json "$config" include "")
    CFG_EXCLUDE=$(_read_json "$config" exclude "")

    [[ -n "$CFG_COMMAND" ]] || die "'command' field required in config"
    [[ -n "$CFG_BINDIR" ]] || die "'bindir' field required in config"
    [[ -d "$CFG_BINDIR" ]] || die "bindir '$CFG_BINDIR' not found. Run 'make' first."

    if [[ -z "$CFG_LOGDIR" ]]; then
        CFG_LOGDIR="logs/$(date +%Y%m%d_%H%M%S)"
    fi

    _resolve_command_templates
}

# Resolve template variables in CFG_COMMAND (first stage — env/install paths)
_resolve_command_templates() {
    CFG_COMMAND="${CFG_COMMAND//\{spike\}/$SPIKE_BIN}"
    CFG_COMMAND="${CFG_COMMAND//\{pk\}/$SPIKE_PK}"
    CFG_COMMAND="${CFG_COMMAND//\{march\}/$MARCH}"
}
