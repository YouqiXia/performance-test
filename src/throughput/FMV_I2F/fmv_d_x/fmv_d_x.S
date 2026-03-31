    .text

# --- FMV.D.X: INT→FP bits double ---
# Dispatch: FMV.I2F → INT Pipe 3
# Expected throughput=1, latency=1 (FU) / 2 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fmv_d_x
    .balign 4
test_fmv_d_x:
    mv   t3, a0
    li  a5, 42
.L_fmv_d_x_loop:
    beqz t3, .L_fmv_d_x_done
    .rept 25
    fmv.d.x  ft0, a5
    fmv.d.x  ft1, a5
    fmv.d.x  ft2, a5
    fmv.d.x  ft3, a5
    .endr
    addi t3, t3, -1
    j    .L_fmv_d_x_loop
.L_fmv_d_x_done:
    ret
