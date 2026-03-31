    .text

# --- CTZW: CTZ word ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_ctzw
    .balign 4
test_ctzw:
    mv   t3, a0
    li  a5, 0x5A5A5A5A
.L_ctzw_loop:
    beqz t3, .L_ctzw_done
    .rept 25
    ctzw  t0, a5
    ctzw  t1, a5
    ctzw  t2, a5
    ctzw  t4, a5
    .endr
    addi t3, t3, -1
    j    .L_ctzw_loop
.L_ctzw_done:
    ret
