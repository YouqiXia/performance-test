#include "src/memory_order/common.h"
    .text

# --- L1 Store Buffer Case B: 1 慢 store + NFAST 快 ld（不同地址） ---
# div t0,t0,t2 制造慢 store data + sd + NFAST 快 ld 从 a2 不同偏移
# insn_per_iter = NFAST + 2, .rept 8
    .global test_sb_case_b
    .balign 4
test_sb_case_b:
    mv   t3, a0
    li   t0, 42
    li   t2, 1
.L_sb_b_loop:
    beqz t3, .L_sb_b_done
    .rept 8
    div  t0, t0, t2
    sd   t0, 0(a1)
    emit_fast_ld_diff a2
    .endr
    addi t3, t3, -1
    j    .L_sb_b_loop
.L_sb_b_done:
    ret
