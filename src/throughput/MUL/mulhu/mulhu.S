    .text

# --- MULHU: (rs1*rs2)[127:64] u*u ---
# Dispatch: MUL → INT Pipe 2
# Expected throughput=1, latency=3
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_mulhu
    .balign 4
test_mulhu:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_mulhu_loop:
    beqz t3, .L_mulhu_done
    .rept 25
    mulhu  t0, a5, a6
    mulhu  t1, a5, a6
    mulhu  t2, a5, a6
    mulhu  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_mulhu_loop
.L_mulhu_done:
    ret
