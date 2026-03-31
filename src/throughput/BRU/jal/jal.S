    .text

# --- JAL: rd=PC+4; PC+=off ---
# Dispatch: BRU → INT Pipe 1
# Expected throughput=1, latency=1
# 1 independent insns × .rept 100 = 100 insns/loop

    .global test_jal
    .balign 4
test_jal:
    mv   t3, a0
.L_jal_loop:
    beqz t3, .L_jal_done
    .rept 100
    jal  t0, .+4
    .endr
    addi t3, t3, -1
    j    .L_jal_loop
.L_jal_done:
    ret
