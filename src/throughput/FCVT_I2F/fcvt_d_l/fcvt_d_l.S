    .text

# --- FCVT.D.L: double←int64 ---
# Dispatch: FCVT.I2F → INT Pipe 3
# Expected throughput=1, latency=4 (FU) / 5 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fcvt_d_l
    .balign 4
test_fcvt_d_l:
    mv   t3, a0
    li  a5, 42
.L_fcvt_d_l_loop:
    beqz t3, .L_fcvt_d_l_done
    .rept 25
    fcvt.d.l  ft0, a5
    fcvt.d.l  ft1, a5
    fcvt.d.l  ft2, a5
    fcvt.d.l  ft3, a5
    .endr
    addi t3, t3, -1
    j    .L_fcvt_d_l_loop
.L_fcvt_d_l_done:
    ret
