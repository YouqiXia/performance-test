    .text

# --- AMOMAX.W: Atomic max signed W ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amomax_w
    .balign 4
test_amomax_w:
    mv   t3, a0
    li  a5, 0
.L_amomax_w_loop:
    beqz t3, .L_amomax_w_done
    .rept 5
    amomax.w  t0, a5, (a1)
    amomax.w  t1, a5, (a1)
    amomax.w  t2, a5, (a1)
    amomax.w  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amomax_w_loop
.L_amomax_w_done:
    ret
