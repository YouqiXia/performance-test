/* Workload: in-place string reverse */
#include <stdint.h>
#define NLOOP CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_str_reverse(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_str_reverse(10);
    perf_start(&ctx);
    test_str_reverse(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("str_reverse", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
