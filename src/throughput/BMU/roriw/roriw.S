    .text

# --- RORIW: rotate right word imm ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_roriw
    .balign 4
test_roriw:
    mv   t3, a0
    li  a5, 42
.L_roriw_loop:
    beqz t3, .L_roriw_done
    .rept 25
    roriw  t0, a5, 1
    roriw  t1, a5, 1
    roriw  t2, a5, 1
    roriw  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_roriw_loop
.L_roriw_done:
    ret
