/* Workload: Iterative Fibonacci fib(20) */
#include <stdint.h>
#define NLOOP CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_fib_iterative(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_fib_iterative(10);
    perf_start(&ctx);
    test_fib_iterative(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("fib_iterative", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
