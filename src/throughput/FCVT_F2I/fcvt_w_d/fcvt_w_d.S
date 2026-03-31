    .text

# --- FCVT.W.D: int32←double ---
# Dispatch: FCVT.F2I → FP Pipe 1
# Expected throughput=1, latency=2 (FU) / 3 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fcvt_w_d
    .balign 4
test_fcvt_w_d:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fcvt_w_d_loop:
    beqz t3, .L_fcvt_w_d_done
    .rept 25
    fcvt.w.d  t0, ft8
    fcvt.w.d  t1, ft8
    fcvt.w.d  t2, ft8
    fcvt.w.d  t4, ft8
    .endr
    addi t3, t3, -1
    j    .L_fcvt_w_d_loop
.L_fcvt_w_d_done:
    ret
