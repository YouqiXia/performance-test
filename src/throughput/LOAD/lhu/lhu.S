    .text

# --- LHU: zext half ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_lhu
    .balign 4
test_lhu:
    mv   t3, a0
.L_lhu_loop:
    beqz t3, .L_lhu_done
    .rept 25
    lhu  t0, 0(a1)
    lhu  t1, 8(a1)
    lhu  t2, 16(a1)
    lhu  t4, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_lhu_loop
.L_lhu_done:
    ret
