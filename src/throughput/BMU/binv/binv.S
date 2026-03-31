    .text

# --- BINV: rs1^(1<<rs2) ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_binv
    .balign 4
test_binv:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_binv_loop:
    beqz t3, .L_binv_done
    .rept 25
    binv  t0, a5, a6
    binv  t1, a5, a6
    binv  t2, a5, a6
    binv  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_binv_loop
.L_binv_done:
    ret
