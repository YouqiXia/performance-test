/* Workload: Edit distance DP on two short strings */
#include <stdint.h>
#define NLOOP CALC_NLOOP(20000)
#include "perf_helpers.h"

extern void test_edit_distance(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_edit_distance(10);
    perf_start(&ctx);
    test_edit_distance(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("edit_distance", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
