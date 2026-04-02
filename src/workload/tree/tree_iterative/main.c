/* Workload: Iterative inorder traversal of 4-node BST */
#include <stdint.h>
#define NLOOP CALC_NLOOP(100)
#include "perf_helpers.h"

extern void test_tree_iterative(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_tree_iterative(10);
    perf_start(&ctx);
    test_tree_iterative(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("tree_iterative", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
