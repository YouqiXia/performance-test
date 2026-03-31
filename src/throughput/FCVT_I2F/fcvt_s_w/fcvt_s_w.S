    .text

# --- FCVT.S.W: single←int32 ---
# Dispatch: FCVT.I2F → INT Pipe 3
# Expected throughput=1, latency=4 (FU) / 5 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fcvt_s_w
    .balign 4
test_fcvt_s_w:
    mv   t3, a0
    li  a5, 42
.L_fcvt_s_w_loop:
    beqz t3, .L_fcvt_s_w_done
    .rept 25
    fcvt.s.w  ft0, a5
    fcvt.s.w  ft1, a5
    fcvt.s.w  ft2, a5
    fcvt.s.w  ft3, a5
    .endr
    addi t3, t3, -1
    j    .L_fcvt_s_w_loop
.L_fcvt_s_w_done:
    ret
