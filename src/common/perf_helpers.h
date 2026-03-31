#ifndef PERF_HELPERS_H
#define PERF_HELPERS_H

#include <stdint.h>

typedef struct {
    int fd_cycles;
    int fd_instret;
} perf_ctx_t;

/* Initialize perf_event counters (cycles + instructions).
 * Falls back to rdcycle/rdinstret if perf_event_open fails. */
perf_ctx_t perf_init(void);

/* Reset and enable counters */
void perf_start(perf_ctx_t *ctx);

/* Disable counters and read values */
void perf_stop(perf_ctx_t *ctx, uint64_t *cycles, uint64_t *instret);

/* Close file descriptors */
void perf_close(perf_ctx_t *ctx);

/* Print one test result */
void perf_print(const char *name, uint64_t cycles, uint64_t instret,
                uint64_t total_iters, uint64_t instr_per_iter);

/* Instruction budget: spike ~100K to keep simulation fast; Linux can afford more */
#ifdef USE_SPIKE
#define INSN_BUDGET  100000ULL
#else
#define INSN_BUDGET  200000000ULL
#endif

/*
 * CALC_NLOOP(insn_per_iter) — compute outer-loop count from per-iteration
 * instruction cost.  Each test #defines NLOOP before including this header:
 *
 *   #define NLOOP  CALC_NLOOP(300)   // .rept=100 × max 3 insn/iter
 *   #include "perf_helpers.h"
 *
 * insn_per_iter = max(.rept × insn_per_iter) across all variants in that test.
 * Floor of 100 prevents degenerate cases.
 */
#ifdef USE_SPIKE
#define CALC_NLOOP(insn_per_iter) \
    (((INSN_BUDGET) / (insn_per_iter)) > 10 ? ((INSN_BUDGET) / (insn_per_iter)) : 10)
#else
#define CALC_NLOOP(insn_per_iter) \
    (((INSN_BUDGET) / (insn_per_iter)) > 100 ? ((INSN_BUDGET) / (insn_per_iter)) : 100)
#endif

#endif /* PERF_HELPERS_H */
