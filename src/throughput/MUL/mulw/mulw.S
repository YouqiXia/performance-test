    .text

# --- MULW: sext32((rs1*rs2)[31:0]) ---
# Dispatch: MUL → INT Pipe 2
# Expected throughput=1, latency=3
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_mulw
    .balign 4
test_mulw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_mulw_loop:
    beqz t3, .L_mulw_done
    .rept 25
    mulw  t0, a5, a6
    mulw  t1, a5, a6
    mulw  t2, a5, a6
    mulw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_mulw_loop
.L_mulw_done:
    ret
