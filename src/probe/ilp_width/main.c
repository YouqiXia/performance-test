/*
 * ilp_width — Issue Width Probe
 *
 * Sweep K from 1..8 parallel independent `addi` chains. Per outer iteration
 * the total issued integer-ALU insn count is ~64 (constant); cycles/outer-iter
 * therefore reflects effective parallel issue throughput.
 *
 * Expected curve: cycles/outer-iter roughly halves K=1→K=2→K=4 up to
 * machine dispatch width W, then plateaus for K>W.
 * IPC plateau value ≈ W (caveat: nearly-zero front-end stalls assumed).
 *
 * This is the first PoC case for the probe/ harness; methodology is trivial
 * and the detector (plateau) is stable, so it serves as a smoke test of the
 * JSON contract + probe_report.py.
 */

#include <stdio.h>
#include <stdint.h>
#include "arch_params.h"
#define NLOOP  CALC_NLOOP(64)   /* each outer iter issues ~64 insns */
#include "perf_helpers.h"
#include "probe_helpers.h"

extern void test_ilp_1(uint64_t);
extern void test_ilp_2(uint64_t);
extern void test_ilp_3(uint64_t);
extern void test_ilp_4(uint64_t);
extern void test_ilp_5(uint64_t);
extern void test_ilp_6(uint64_t);
extern void test_ilp_7(uint64_t);
extern void test_ilp_8(uint64_t);

typedef void (*ilp_fn)(uint64_t);

struct variant {
    int k;
    int insn_per_iter;   /* total addi count per outer iter */
    ilp_fn fn;
};

static const struct variant variants[] = {
    {1, 64, test_ilp_1},
    {2, 64, test_ilp_2},
    {3, 63, test_ilp_3},
    {4, 64, test_ilp_4},
    {5, 60, test_ilp_5},
    {6, 60, test_ilp_6},
    {7, 63, test_ilp_7},
    {8, 64, test_ilp_8},
};

int main(void)
{
    perf_ctx_t ctx = perf_init();
    probe_ctx_t probe;

    printf("=== ILP Width Probe ===\n");
    printf("arch=%s NLOOP=%llu\n\n", ARCH_NAME, (unsigned long long)NLOOP);

    probe_begin(&probe, "ilp_width", "K_chains", "ipc");

    for (size_t i = 0; i < sizeof(variants)/sizeof(variants[0]); i++) {
        const struct variant *v = &variants[i];
        uint64_t cycles = 0, instret = 0;

        /* warmup */
        v->fn(NLOOP / 100 + 1);

        perf_start(&ctx);
        v->fn(NLOOP);
        perf_stop(&ctx, &cycles, &instret);

        uint64_t total_iters = (uint64_t)NLOOP;
        char name[32];
        snprintf(name, sizeof(name), "ilp K=%d", v->k);
        perf_print(name, cycles, instret, total_iters, v->insn_per_iter);
        probe_emit_point(&probe, v->k, cycles, instret,
                         total_iters, v->insn_per_iter);
    }

    probe_end(&probe);
    perf_close(&ctx);
    return 0;
}
