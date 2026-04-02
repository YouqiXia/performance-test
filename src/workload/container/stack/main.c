/* Workload: stack push/pop (16 pairs per iteration) */
#include <stdint.h>
#define NLOOP CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_stack(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_stack(10);
    perf_start(&ctx);
    test_stack(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("stack", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
