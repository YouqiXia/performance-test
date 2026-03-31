    .text

# --- SLLI.UW: zext32(rs1)<<shamt ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_slli_uw
    .balign 4
test_slli_uw:
    mv   t3, a0
    li  a5, 42
.L_slli_uw_loop:
    beqz t3, .L_slli_uw_done
    .rept 25
    slli.uw  t0, a5, 1
    slli.uw  t1, a5, 1
    slli.uw  t2, a5, 1
    slli.uw  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_slli_uw_loop
.L_slli_uw_done:
    ret
