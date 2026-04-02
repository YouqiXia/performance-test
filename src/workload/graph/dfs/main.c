/* Workload: DFS on 5-vertex graph */
#include <stdint.h>
#define NLOOP CALC_NLOOP(500)
#include "perf_helpers.h"

extern void test_dfs(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_dfs(10);
    perf_start(&ctx);
    test_dfs(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("dfs", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
