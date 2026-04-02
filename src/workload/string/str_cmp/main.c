/* Workload: string compare (strcmp-like) */
#include <stdint.h>
#define NLOOP CALC_NLOOP(700)
#include "perf_helpers.h"

extern void test_str_cmp(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_str_cmp(10);
    perf_start(&ctx);
    test_str_cmp(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("str_cmp", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
