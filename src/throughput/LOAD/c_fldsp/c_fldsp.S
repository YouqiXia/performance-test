    .text

# --- C.FLDSP: FP double from SP ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_fldsp
    .balign 4
test_c_fldsp:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
    addi sp, sp, -256
.L_c_fldsp_loop:
    beqz t3, .L_c_fldsp_done
    .rept 25
    c.fldsp  ft0, 0(sp)
    c.fldsp  ft1, 8(sp)
    c.fldsp  ft2, 16(sp)
    c.fldsp  ft3, 24(sp)
    .endr
    addi t3, t3, -1
    j    .L_c_fldsp_loop
.L_c_fldsp_done:
    addi sp, sp, 256
    ret
