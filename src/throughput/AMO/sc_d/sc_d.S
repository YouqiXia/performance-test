    .text

# --- SC.D: Store-conditional D ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_sc_d
    .balign 4
test_sc_d:
    mv   t3, a0
    li  a5, 0
.L_sc_d_loop:
    beqz t3, .L_sc_d_done
    .rept 5
    sc.d  t0, a5, (a1)
    sc.d  t1, a5, (a1)
    sc.d  t2, a5, (a1)
    sc.d  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_sc_d_loop
.L_sc_d_done:
    ret
