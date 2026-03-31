    .text

# --- C.FLD: FP double ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_fld
    .balign 4
test_c_fld:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
    addi sp, sp, -16
    sd   s0, 0(sp)
    mv   s0, a1
.L_c_fld_loop:
    beqz t3, .L_c_fld_done
    .rept 25
    c.fld  fa2, 0(s0)
    c.fld  fa3, 8(s0)
    c.fld  fa4, 16(s0)
    c.fld  fa5, 24(s0)
    .endr
    addi t3, t3, -1
    j    .L_c_fld_loop
.L_c_fld_done:
    ld   s0, 0(sp)
    addi sp, sp, 16
    ret
