/* Workload: Huffman tree construction */
#include <stdint.h>
#define NLOOP CALC_NLOOP(80)
#include "perf_helpers.h"

extern void test_huffman(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_huffman(10);
    perf_start(&ctx);
    test_huffman(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("huffman", cycles, instret, (uint64_t)NLOOP, 1);
    perf_close(&ctx);
    return 0;
}
