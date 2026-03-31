    .text

# --- AMOAND.D: Atomic AND D ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amoand_d
    .balign 4
test_amoand_d:
    mv   t3, a0
    li  a5, 0
.L_amoand_d_loop:
    beqz t3, .L_amoand_d_done
    .rept 5
    amoand.d  t0, a5, (a1)
    amoand.d  t1, a5, (a1)
    amoand.d  t2, a5, (a1)
    amoand.d  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amoand_d_loop
.L_amoand_d_done:
    ret
