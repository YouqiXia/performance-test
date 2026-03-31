    .text

# --- MULHSU: (rs1*rs2)[127:64] s*u ---
# Dispatch: MUL → INT Pipe 2
# Expected throughput=1, latency=3
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_mulhsu
    .balign 4
test_mulhsu:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_mulhsu_loop:
    beqz t3, .L_mulhsu_done
    .rept 25
    mulhsu  t0, a5, a6
    mulhsu  t1, a5, a6
    mulhsu  t2, a5, a6
    mulhsu  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_mulhsu_loop
.L_mulhsu_done:
    ret
