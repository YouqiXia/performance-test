/* L1 Store Buffer Case B: 1 慢 store + NFAST 快 ld（不同地址）
 * 测 store buffer 是否让 load 绕过 data 慢的 store */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "src/memory_order/common.h"

#define NLOOP  CALC_NLOOP((NFAST + 2) * 8)
#include "perf_helpers.h"

extern void test_sb_case_b(uint64_t nloop, uint64_t *store_buf, uint64_t *load_buf);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    uint64_t store_buf[8] __attribute__((aligned(64)));
    memset(store_buf, 0, sizeof(store_buf));
    uint64_t load_buf[64] __attribute__((aligned(64)));
    memset(load_buf, 0, sizeof(load_buf));

    test_sb_case_b(1000, store_buf, load_buf);
    perf_start(&ctx);
    test_sb_case_b(NLOOP, store_buf, load_buf);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("SB diff", cycles, instret,
              (uint64_t)NLOOP * 8, NFAST + 2);
    perf_close(&ctx);
    return 0;
}
