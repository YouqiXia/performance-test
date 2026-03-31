    .text

# --- ROLW: rotate left word ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_rolw
    .balign 4
test_rolw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_rolw_loop:
    beqz t3, .L_rolw_done
    .rept 25
    rolw  t0, a5, a6
    rolw  t1, a5, a6
    rolw  t2, a5, a6
    rolw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_rolw_loop
.L_rolw_done:
    ret
