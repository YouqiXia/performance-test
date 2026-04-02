#include "src/store/common.h"
    .text

# --- L2 Load-Load Case C: 1 慢 ld + NFAST 快 ld（同地址，t0==a2） ---
# div t0,t0,t2 使老 load 地址晚到 + ld t5,0(t0)
# NFAST 快 ld 全部读 0(a2)，t0==a2 → 同地址
# t0 初始化为 a2
# insn_per_iter = NFAST + 2, .rept 8
    .global test_ll_case_c
    .balign 4
test_ll_case_c:
    mv   t3, a0
    mv   t0, a2
    li   t2, 1
.L_ll_c_loop:
    beqz t3, .L_ll_c_done
    .rept 8
    div  t0, t0, t2
    ld   t5, 0(t0)
    emit_fast_ld_same a2
    .endr
    addi t3, t3, -1
    j    .L_ll_c_loop
.L_ll_c_done:
    ret
