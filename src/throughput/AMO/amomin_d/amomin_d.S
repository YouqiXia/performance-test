    .text

# --- AMOMIN.D: Atomic min signed D ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amomin_d
    .balign 4
test_amomin_d:
    mv   t3, a0
    li  a5, 0
.L_amomin_d_loop:
    beqz t3, .L_amomin_d_done
    .rept 5
    amomin.d  t0, a5, (a1)
    amomin.d  t1, a5, (a1)
    amomin.d  t2, a5, (a1)
    amomin.d  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amomin_d_loop
.L_amomin_d_done:
    ret
