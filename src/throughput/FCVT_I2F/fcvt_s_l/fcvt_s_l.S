    .text

# --- FCVT.S.L: single←int64 ---
# Dispatch: FCVT.I2F → INT Pipe 3
# Expected throughput=1, latency=4 (FU) / 5 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fcvt_s_l
    .balign 4
test_fcvt_s_l:
    mv   t3, a0
    li  a5, 42
.L_fcvt_s_l_loop:
    beqz t3, .L_fcvt_s_l_done
    .rept 25
    fcvt.s.l  ft0, a5
    fcvt.s.l  ft1, a5
    fcvt.s.l  ft2, a5
    fcvt.s.l  ft3, a5
    .endr
    addi t3, t3, -1
    j    .L_fcvt_s_l_loop
.L_fcvt_s_l_done:
    ret
