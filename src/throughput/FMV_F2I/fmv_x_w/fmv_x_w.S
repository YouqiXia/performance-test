    .text

# --- FMV.X.W: FP→INT bits single ---
# Dispatch: FMV.F2I → FP Pipe 1
# Expected throughput=1, latency=1 (FU) / 2 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fmv_x_w
    .balign 4
test_fmv_x_w:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fmv_x_w_loop:
    beqz t3, .L_fmv_x_w_done
    .rept 25
    fmv.x.w  t0, ft8
    fmv.x.w  t1, ft8
    fmv.x.w  t2, ft8
    fmv.x.w  t4, ft8
    .endr
    addi t3, t3, -1
    j    .L_fmv_x_w_loop
.L_fmv_x_w_done:
    ret
