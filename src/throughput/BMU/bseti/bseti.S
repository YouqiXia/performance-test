    .text

# --- BSETI: rs1|(1<<shamt) ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_bseti
    .balign 4
test_bseti:
    mv   t3, a0
    li  a5, 42
.L_bseti_loop:
    beqz t3, .L_bseti_done
    .rept 25
    bseti  t0, a5, 1
    bseti  t1, a5, 1
    bseti  t2, a5, 1
    bseti  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_bseti_loop
.L_bseti_done:
    ret
