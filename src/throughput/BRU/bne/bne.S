    .text

# --- BNE: branch if rs1!=rs2 ---
# Dispatch: BRU → INT Pipe 1
# Expected throughput=1, latency=1
# 1 independent insns × .rept 100 = 100 insns/loop

    .global test_bne
    .balign 4
test_bne:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_bne_loop:
    beqz t3, .L_bne_done
    .rept 100
    bne  a5, a5, .+4
    .endr
    addi t3, t3, -1
    j    .L_bne_loop
.L_bne_done:
    ret
