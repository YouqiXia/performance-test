    .text

# --- RORW: rotate right word ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_rorw
    .balign 4
test_rorw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_rorw_loop:
    beqz t3, .L_rorw_done
    .rept 25
    rorw  t0, a5, a6
    rorw  t1, a5, a6
    rorw  t2, a5, a6
    rorw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_rorw_loop
.L_rorw_done:
    ret
