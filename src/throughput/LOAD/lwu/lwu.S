    .text

# --- LWU: zext word ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_lwu
    .balign 4
test_lwu:
    mv   t3, a0
.L_lwu_loop:
    beqz t3, .L_lwu_done
    .rept 25
    lwu  t0, 0(a1)
    lwu  t1, 8(a1)
    lwu  t2, 16(a1)
    lwu  t4, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_lwu_loop
.L_lwu_done:
    ret
