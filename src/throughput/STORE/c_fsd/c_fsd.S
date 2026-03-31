    .text

# --- C.FSD: FP double store ---
# Dispatch: STORE → MEM Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_fsd
    .balign 4
test_c_fsd:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
    addi sp, sp, -16
    sd   s0, 0(sp)
    mv   s0, a1
    # Init fa2 (f12) to valid double
    li   t5, 0x3FF0000000000000
    fmv.d.x fa2, t5
.L_c_fsd_loop:
    beqz t3, .L_c_fsd_done
    .rept 25
    c.fsd  fa2, 0(s0)
    c.fsd  fa2, 8(s0)
    c.fsd  fa2, 16(s0)
    c.fsd  fa2, 24(s0)
    .endr
    addi t3, t3, -1
    j    .L_c_fsd_loop
.L_c_fsd_done:
    ld   s0, 0(sp)
    addi sp, sp, 16
    ret
