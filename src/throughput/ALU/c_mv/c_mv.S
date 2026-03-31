    .text

# --- C.MV: rd=rs2 ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_mv
    .balign 4
test_c_mv:
    mv   t3, a0
    li  a5, 1
.L_c_mv_loop:
    beqz t3, .L_c_mv_done
    .rept 25
    c.mv  t0, a5
    c.mv  t1, a5
    c.mv  t2, a5
    c.mv  t4, a5
    .endr
    addi t3, t3, -1
    j    .L_c_mv_loop
.L_c_mv_done:
    ret
