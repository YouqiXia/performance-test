    .text

# --- C.FSDSP: FP double store SP ---
# Dispatch: STORE → MEM Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_fsdsp
    .balign 4
test_c_fsdsp:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
    addi sp, sp, -256
.L_c_fsdsp_loop:
    beqz t3, .L_c_fsdsp_done
    .rept 25
    c.fsdsp  ft8, 0(sp)
    c.fsdsp  ft8, 8(sp)
    c.fsdsp  ft8, 16(sp)
    c.fsdsp  ft8, 24(sp)
    .endr
    addi t3, t3, -1
    j    .L_c_fsdsp_loop
.L_c_fsdsp_done:
    addi sp, sp, 256
    ret
