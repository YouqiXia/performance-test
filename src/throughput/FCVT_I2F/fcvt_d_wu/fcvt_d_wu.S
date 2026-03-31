    .text

# --- FCVT.D.WU: double←uint32 ---
# Dispatch: FCVT.I2F → INT Pipe 3
# Expected throughput=1, latency=4 (FU) / 5 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fcvt_d_wu
    .balign 4
test_fcvt_d_wu:
    mv   t3, a0
    li  a5, 42
.L_fcvt_d_wu_loop:
    beqz t3, .L_fcvt_d_wu_done
    .rept 25
    fcvt.d.wu  ft0, a5
    fcvt.d.wu  ft1, a5
    fcvt.d.wu  ft2, a5
    fcvt.d.wu  ft3, a5
    .endr
    addi t3, t3, -1
    j    .L_fcvt_d_wu_loop
.L_fcvt_d_wu_done:
    ret
