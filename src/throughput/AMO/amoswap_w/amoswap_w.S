    .text

# --- AMOSWAP.W: Atomic swap W ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amoswap_w
    .balign 4
test_amoswap_w:
    mv   t3, a0
    li  a5, 0
.L_amoswap_w_loop:
    beqz t3, .L_amoswap_w_done
    .rept 5
    amoswap.w  t0, a5, (a1)
    amoswap.w  t1, a5, (a1)
    amoswap.w  t2, a5, (a1)
    amoswap.w  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amoswap_w_loop
.L_amoswap_w_done:
    ret
