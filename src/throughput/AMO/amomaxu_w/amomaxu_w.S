    .text

# --- AMOMAXU.W: Atomic max unsigned W ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amomaxu_w
    .balign 4
test_amomaxu_w:
    mv   t3, a0
    li  a5, 0
.L_amomaxu_w_loop:
    beqz t3, .L_amomaxu_w_done
    .rept 5
    amomaxu.w  t0, a5, (a1)
    amomaxu.w  t1, a5, (a1)
    amomaxu.w  t2, a5, (a1)
    amomaxu.w  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amomaxu_w_loop
.L_amomaxu_w_done:
    ret
