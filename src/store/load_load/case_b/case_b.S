#include "src/store/common.h"
    .text

# --- L2 Load-Load Case B: 1 慢 ld + NFAST 快 ld（不同地址） ---
# div t0,t0,t2 使老 load 地址晚到 + ld t5,0(t0)
# NFAST 快 ld 从 a2 不同偏移读
# t0 初始化为 a1（老 load 读 slow_buf）
# insn_per_iter = NFAST + 2, .rept 8
    .global test_ll_case_b
    .balign 4
test_ll_case_b:
    mv   t3, a0
    mv   t0, a1
    li   t2, 1
.L_ll_b_loop:
    beqz t3, .L_ll_b_done
    .rept 8
    div  t0, t0, t2
    ld   t5, 0(t0)
    emit_fast_ld_diff a2
    .endr
    addi t3, t3, -1
    j    .L_ll_b_loop
.L_ll_b_done:
    ret
