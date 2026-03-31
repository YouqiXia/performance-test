    .text

# --- FLE.D: FP less-equal double ---
# Dispatch: FCMP → FP Pipe 1
# Expected throughput=1, latency=4 (FU) / 5 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fle_d
    .balign 4
test_fle_d:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fle_d_loop:
    beqz t3, .L_fle_d_done
    .rept 25
    fle.d  t0, ft8, ft9
    fle.d  t1, ft8, ft9
    fle.d  t2, ft8, ft9
    fle.d  t4, ft8, ft9
    .endr
    addi t3, t3, -1
    j    .L_fle_d_loop
.L_fle_d_done:
    ret
