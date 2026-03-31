    .text

# --- LR.W: Load-reserved W ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_lr_w
    .balign 4
test_lr_w:
    mv   t3, a0
.L_lr_w_loop:
    beqz t3, .L_lr_w_done
    .rept 5
    lr.w  t0, (a1)
    lr.w  t1, (a1)
    lr.w  t2, (a1)
    lr.w  t4, (a1)
    .endr
    addi t3, t3, -1
    j    .L_lr_w_loop
.L_lr_w_done:
    ret
