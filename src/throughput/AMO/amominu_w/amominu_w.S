    .text

# --- AMOMINU.W: Atomic min unsigned W ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amominu_w
    .balign 4
test_amominu_w:
    mv   t3, a0
    li  a5, 0
.L_amominu_w_loop:
    beqz t3, .L_amominu_w_done
    .rept 5
    amominu.w  t0, a5, (a1)
    amominu.w  t1, a5, (a1)
    amominu.w  t2, a5, (a1)
    amominu.w  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amominu_w_loop
.L_amominu_w_done:
    ret
