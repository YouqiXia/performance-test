/* Dependency test: ALU↔DIV forwarding chain */
#include <stdio.h>
#include <stdint.h>
#define NLOOP  CALC_NLOOP(40)
#include "perf_helpers.h"

extern void test_alu_div(uint64_t nloop);

int main(void)
{
    perf_ctx_t ctx = perf_init();
    uint64_t cycles, instret;
    test_alu_div(1000);
    perf_start(&ctx);
    test_alu_div(NLOOP);
    perf_stop(&ctx, &cycles, &instret);
    perf_print("ALU<->DIV fwd", cycles, instret,
              (uint64_t)NLOOP * 20, 2);
    perf_close(&ctx);
    return 0;
}
