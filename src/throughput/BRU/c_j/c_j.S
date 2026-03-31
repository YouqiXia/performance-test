    .text

# --- C.J: PC+=off ---
# Dispatch: BRU → INT Pipe 1
# Expected throughput=1, latency=1
# 1 independent insns × .rept 100 = 100 insns/loop

    .global test_c_j
    .balign 4
test_c_j:
    mv   t3, a0
.L_c_j_loop:
    beqz t3, .L_c_j_done
    .rept 100
    c.j  .+4
    .endr
    addi t3, t3, -1
    j    .L_c_j_loop
.L_c_j_done:
    ret
