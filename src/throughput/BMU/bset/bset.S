    .text

# --- BSET: rs1|(1<<rs2) ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_bset
    .balign 4
test_bset:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_bset_loop:
    beqz t3, .L_bset_done
    .rept 25
    bset  t0, a5, a6
    bset  t1, a5, a6
    bset  t2, a5, a6
    bset  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_bset_loop
.L_bset_done:
    ret
