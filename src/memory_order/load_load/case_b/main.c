/* L2 Load-Load Case B: 1 慢 ld + NFAST 快 ld（不同地址）
 * 测快 load 是否绕过地址慢的老 load */
#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "src/memory_order/common.h"

#define NLOOP  CALC_NLOOP((NFAST + 2) * 8)
#include "perf_helpers.h"

extern void test_ll_case_b(uint64_t nloop, uint64_t *slow_buf, uint64_t *fast_buf);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;

    uint64_t slow_buf[8] __attribute__((aligned(64)));
    memset(slow_buf, 0, sizeof(slow_buf));
    uint64_t fast_buf[64] __attribute__((aligned(64)));
    memset(fast_buf, 0, sizeof(fast_buf));

    test_ll_case_b(1000, slow_buf, fast_buf);
    perf_start(&ctx);
    test_ll_case_b(NLOOP, slow_buf, fast_buf);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("LL diff", cycles, instret,
              (uint64_t)NLOOP * 8, NFAST + 2);
    perf_close(&ctx);
    return 0;
}
