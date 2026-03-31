    .text

# --- FSH: FP half store ---
# Dispatch: STORE → MEM Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fsh
    .balign 4
test_fsh:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fsh_loop:
    beqz t3, .L_fsh_done
    .rept 25
    fsh  ft8, 0(a1)
    fsh  ft8, 8(a1)
    fsh  ft8, 16(a1)
    fsh  ft8, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_fsh_loop
.L_fsh_done:
    ret
