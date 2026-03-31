    .text

# --- FCVT.D.W: double←int32 ---
# Dispatch: FCVT.I2F → INT Pipe 3
# Expected throughput=1, latency=4 (FU) / 5 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fcvt_d_w
    .balign 4
test_fcvt_d_w:
    mv   t3, a0
    li  a5, 42
.L_fcvt_d_w_loop:
    beqz t3, .L_fcvt_d_w_done
    .rept 25
    fcvt.d.w  ft0, a5
    fcvt.d.w  ft1, a5
    fcvt.d.w  ft2, a5
    fcvt.d.w  ft3, a5
    .endr
    addi t3, t3, -1
    j    .L_fcvt_d_w_loop
.L_fcvt_d_w_done:
    ret
