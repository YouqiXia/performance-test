    .text

# --- LR.D: Load-reserved D ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_lr_d
    .balign 4
test_lr_d:
    mv   t3, a0
.L_lr_d_loop:
    beqz t3, .L_lr_d_done
    .rept 5
    lr.d  t0, (a1)
    lr.d  t1, (a1)
    lr.d  t2, (a1)
    lr.d  t4, (a1)
    .endr
    addi t3, t3, -1
    j    .L_lr_d_loop
.L_lr_d_done:
    ret
