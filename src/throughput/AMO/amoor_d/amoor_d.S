    .text

# --- AMOOR.D: Atomic OR D ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amoor_d
    .balign 4
test_amoor_d:
    mv   t3, a0
    li  a5, 0
.L_amoor_d_loop:
    beqz t3, .L_amoor_d_done
    .rept 5
    amoor.d  t0, a5, (a1)
    amoor.d  t1, a5, (a1)
    amoor.d  t2, a5, (a1)
    amoor.d  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amoor_d_loop
.L_amoor_d_done:
    ret
