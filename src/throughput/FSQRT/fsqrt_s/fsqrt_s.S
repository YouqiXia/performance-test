    .text

# --- FSQRT.S: FP sqrt single ---
# Dispatch: FSQRT → FP Pipe 0
# Expected throughput=[TBD], latency=[TBD]
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_fsqrt_s
    .balign 4
test_fsqrt_s:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fsqrt_s_loop:
    beqz t3, .L_fsqrt_s_done
    .rept 5
    fsqrt.s  ft0, ft8
    fsqrt.s  ft1, ft8
    fsqrt.s  ft2, ft8
    fsqrt.s  ft3, ft8
    .endr
    addi t3, t3, -1
    j    .L_fsqrt_s_loop
.L_fsqrt_s_done:
    ret
