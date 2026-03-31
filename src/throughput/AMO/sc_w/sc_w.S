    .text

# --- SC.W: Store-conditional W ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_sc_w
    .balign 4
test_sc_w:
    mv   t3, a0
    li  a5, 0
.L_sc_w_loop:
    beqz t3, .L_sc_w_done
    .rept 5
    sc.w  t0, a5, (a1)
    sc.w  t1, a5, (a1)
    sc.w  t2, a5, (a1)
    sc.w  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_sc_w_loop
.L_sc_w_done:
    ret
