    .text

# --- MULH: (rs1*rs2)[127:64] s*s ---
# Dispatch: MUL → INT Pipe 2
# Expected throughput=1, latency=3
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_mulh
    .balign 4
test_mulh:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_mulh_loop:
    beqz t3, .L_mulh_done
    .rept 25
    mulh  t0, a5, a6
    mulh  t1, a5, a6
    mulh  t2, a5, a6
    mulh  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_mulh_loop
.L_mulh_done:
    ret
