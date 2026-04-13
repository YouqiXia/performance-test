#include "src/memory_order/common.h"
    .text

# --- L1 Store Buffer Case C: 1 慢 store + NFAST 快 ld（同地址 0(a1)） ---
# div t0,t0,t2 + sd + NFAST 快 ld 全部读 0(a1) → 必须等 forwarding
# insn_per_iter = NFAST + 2, .rept 8
    .global test_sb_case_c
    .balign 4
test_sb_case_c:
    mv   t3, a0
    li   t0, 42
    li   t2, 1
.L_sb_c_loop:
    beqz t3, .L_sb_c_done
    .rept 8
    div  t0, t0, t2
    sd   t0, 0(a1)
    emit_fast_ld_same a1
    .endr
    addi t3, t3, -1
    j    .L_sb_c_loop
.L_sb_c_done:
    ret
