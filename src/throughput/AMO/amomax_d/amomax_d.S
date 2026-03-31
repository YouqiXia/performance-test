    .text

# --- AMOMAX.D: Atomic max signed D ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amomax_d
    .balign 4
test_amomax_d:
    mv   t3, a0
    li  a5, 0
.L_amomax_d_loop:
    beqz t3, .L_amomax_d_done
    .rept 5
    amomax.d  t0, a5, (a1)
    amomax.d  t1, a5, (a1)
    amomax.d  t2, a5, (a1)
    amomax.d  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amomax_d_loop
.L_amomax_d_done:
    ret
