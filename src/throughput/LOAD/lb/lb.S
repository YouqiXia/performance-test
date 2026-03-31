    .text

# --- LB: sext byte ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_lb
    .balign 4
test_lb:
    mv   t3, a0
.L_lb_loop:
    beqz t3, .L_lb_done
    .rept 25
    lb  t0, 0(a1)
    lb  t1, 8(a1)
    lb  t2, 16(a1)
    lb  t4, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_lb_loop
.L_lb_done:
    ret
