    .text

# --- SH1ADD: (rs1<<1)+rs2 ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sh1add
    .balign 4
test_sh1add:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_sh1add_loop:
    beqz t3, .L_sh1add_done
    .rept 25
    sh1add  t0, a5, a6
    sh1add  t1, a5, a6
    sh1add  t2, a5, a6
    sh1add  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_sh1add_loop
.L_sh1add_done:
    ret
