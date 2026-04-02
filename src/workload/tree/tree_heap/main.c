/* Workload: Min-heap insert 5 values per iteration */
#include <stdint.h>
#define NLOOP CALC_NLOOP(200)
#include "perf_helpers.h"

extern void test_tree_heap(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_tree_heap(10);
    perf_start(&ctx);
    test_tree_heap(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("tree_heap", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
