    .text

# --- BLT: branch if rs1<rs2 signed ---
# Dispatch: BRU → INT Pipe 1
# Expected throughput=1, latency=1
# 1 independent insns × .rept 100 = 100 insns/loop

    .global test_blt
    .balign 4
test_blt:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_blt_loop:
    beqz t3, .L_blt_done
    .rept 100
    blt  a5, a6, .+4
    .endr
    addi t3, t3, -1
    j    .L_blt_loop
.L_blt_done:
    ret
