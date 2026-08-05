#ifndef PROBE_HELPERS_H
#define PROBE_HELPERS_H

#include <stdint.h>
#include "perf_helpers.h"

/*
 * probe_helpers — structured JSON output for parameter-sweep cases.
 *
 * A probe case drives a sweep variable X (e.g. chain count, working-set size)
 * across N points, measures cycles/instret at each point, and emits a JSON
 * document to stdout. scripts/probe_report.py consumes the JSON, detects the
 * knee/plateau, and compares against reference/<arch>.yaml.
 *
 * Contract:
 *   probe_begin("case_name");
 *   for each sweep point:
 *       probe_emit_point(x_value, cycles, instret, total_iters, instr_per_iter);
 *   probe_end();
 *
 * JSON is written between ##PROBE_JSON_BEGIN## / ##PROBE_JSON_END## markers so
 * it can be extracted from a mixed log stream.
 */

typedef struct {
    const char *case_name;
    int emitted;
} probe_ctx_t;

void probe_begin(probe_ctx_t *p, const char *case_name, const char *x_label, const char *y_unit);

void probe_emit_point(probe_ctx_t *p,
                      long x,
                      uint64_t cycles,
                      uint64_t instret,
                      uint64_t total_iters,
                      uint64_t instr_per_iter);

void probe_end(probe_ctx_t *p);

#endif /* PROBE_HELPERS_H */
