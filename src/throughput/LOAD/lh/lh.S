    .text

# --- LH: sext half ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_lh
    .balign 4
test_lh:
    mv   t3, a0
.L_lh_loop:
    beqz t3, .L_lh_done
    .rept 25
    lh  t0, 0(a1)
    lh  t1, 8(a1)
    lh  t2, 16(a1)
    lh  t4, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_lh_loop
.L_lh_done:
    ret
