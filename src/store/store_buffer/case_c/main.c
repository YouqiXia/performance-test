/* L1 Store Buffer Case C: 1 慢 store + NFAST 快 ld（同地址）
 * 同地址 load 必须等 store forwarding */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "src/store/common.h"

#define NLOOP  CALC_NLOOP((NFAST + 2) * 8)
#include "perf_helpers.h"

extern void test_sb_case_c(uint64_t nloop, uint64_t *store_buf, uint64_t *load_buf);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    uint64_t store_buf[8] __attribute__((aligned(64)));
    memset(store_buf, 0, sizeof(store_buf));
    uint64_t load_buf[64] __attribute__((aligned(64)));
    memset(load_buf, 0, sizeof(load_buf));

    test_sb_case_c(1000, store_buf, load_buf);
    perf_start(&ctx);
    test_sb_case_c(NLOOP, store_buf, load_buf);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("SB same", cycles, instret,
              (uint64_t)NLOOP * 8, NFAST + 2);
    perf_close(&ctx);
    return 0;
}
