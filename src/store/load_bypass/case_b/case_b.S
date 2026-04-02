#include "src/store/common.h"
    .text

# --- L3 Load Bypass Case B: 1 地址慢 store + NFAST 快 ld（不同地址） ---
# div t0,t0,t2 使 store 地址晚到 + sd t3,0(t0)
# NFAST 快 ld 从 a2 不同偏移读
# t0 初始化为 a1（store 写 slow_buf）
# insn_per_iter = NFAST + 2, .rept 8
    .global test_lb_case_b
    .balign 4
test_lb_case_b:
    mv   t3, a0
    mv   t0, a1
    li   t2, 1
.L_lb_b_loop:
    beqz t3, .L_lb_b_done
    .rept 8
    div  t0, t0, t2
    sd   t3, 0(t0)
    emit_fast_ld_diff a2
    .endr
    addi t3, t3, -1
    j    .L_lb_b_loop
.L_lb_b_done:
    ret
