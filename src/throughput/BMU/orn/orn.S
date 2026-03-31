    .text

# --- ORN: rs1|~rs2 ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_orn
    .balign 4
test_orn:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_orn_loop:
    beqz t3, .L_orn_done
    .rept 25
    orn  t0, a5, a6
    orn  t1, a5, a6
    orn  t2, a5, a6
    orn  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_orn_loop
.L_orn_done:
    ret
