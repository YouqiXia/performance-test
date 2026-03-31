    .text

# --- AMOXOR.W: Atomic XOR W ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amoxor_w
    .balign 4
test_amoxor_w:
    mv   t3, a0
    li  a5, 0
.L_amoxor_w_loop:
    beqz t3, .L_amoxor_w_done
    .rept 5
    amoxor.w  t0, a5, (a1)
    amoxor.w  t1, a5, (a1)
    amoxor.w  t2, a5, (a1)
    amoxor.w  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amoxor_w_loop
.L_amoxor_w_done:
    ret
