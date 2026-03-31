    .text

# --- AMOMIN.W: Atomic min signed W ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amomin_w
    .balign 4
test_amomin_w:
    mv   t3, a0
    li  a5, 0
.L_amomin_w_loop:
    beqz t3, .L_amomin_w_done
    .rept 5
    amomin.w  t0, a5, (a1)
    amomin.w  t1, a5, (a1)
    amomin.w  t2, a5, (a1)
    amomin.w  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amomin_w_loop
.L_amomin_w_done:
    ret
