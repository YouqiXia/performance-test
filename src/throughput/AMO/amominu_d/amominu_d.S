    .text

# --- AMOMINU.D: Atomic min unsigned D ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amominu_d
    .balign 4
test_amominu_d:
    mv   t3, a0
    li  a5, 0
.L_amominu_d_loop:
    beqz t3, .L_amominu_d_done
    .rept 5
    amominu.d  t0, a5, (a1)
    amominu.d  t1, a5, (a1)
    amominu.d  t2, a5, (a1)
    amominu.d  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amominu_d_loop
.L_amominu_d_done:
    ret
