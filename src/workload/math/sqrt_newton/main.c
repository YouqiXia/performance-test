/* Workload: Newton-Raphson sqrt (FP stress test) */
#include <stdint.h>
#define NLOOP CALC_NLOOP(500)
#include "perf_helpers.h"

extern void test_sqrt_newton(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_sqrt_newton(10);
    perf_start(&ctx);
    test_sqrt_newton(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("sqrt_newton", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
