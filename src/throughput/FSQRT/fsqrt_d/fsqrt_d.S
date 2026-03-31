    .text

# --- FSQRT.D: FP sqrt double ---
# Dispatch: FSQRT → FP Pipe 0
# Expected throughput=[TBD], latency=[TBD]
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_fsqrt_d
    .balign 4
test_fsqrt_d:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fsqrt_d_loop:
    beqz t3, .L_fsqrt_d_done
    .rept 5
    fsqrt.d  ft0, ft8
    fsqrt.d  ft1, ft8
    fsqrt.d  ft2, ft8
    fsqrt.d  ft3, ft8
    .endr
    addi t3, t3, -1
    j    .L_fsqrt_d_loop
.L_fsqrt_d_done:
    ret
