/* Workload: BST search for value 3 */
#include <stdint.h>
#define NLOOP CALC_NLOOP(50)
#include "perf_helpers.h"

extern void test_tree_search(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_tree_search(10);
    perf_start(&ctx);
    test_tree_search(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("tree_search", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
