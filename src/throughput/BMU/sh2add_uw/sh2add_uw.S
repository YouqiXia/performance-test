    .text

# --- SH2ADD.UW: (zext32(rs1)<<2)+rs2 ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sh2add_uw
    .balign 4
test_sh2add_uw:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_sh2add_uw_loop:
    beqz t3, .L_sh2add_uw_done
    .rept 25
    sh2add.uw  t0, a5, a6
    sh2add.uw  t1, a5, a6
    sh2add.uw  t2, a5, a6
    sh2add.uw  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_sh2add_uw_loop
.L_sh2add_uw_done:
    ret
