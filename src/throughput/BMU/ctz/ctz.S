    .text

# --- CTZ: count trailing zeros ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_ctz
    .balign 4
test_ctz:
    mv   t3, a0
    li  a5, 0x5A5A5A5A
.L_ctz_loop:
    beqz t3, .L_ctz_done
    .rept 25
    ctz  t0, a5
    ctz  t1, a5
    ctz  t2, a5
    ctz  t4, a5
    .endr
    addi t3, t3, -1
    j    .L_ctz_loop
.L_ctz_done:
    ret
