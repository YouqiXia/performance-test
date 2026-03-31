    .text

# --- BCLRI: rs1&~(1<<shamt) ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_bclri
    .balign 4
test_bclri:
    mv   t3, a0
    li  a5, 42
.L_bclri_loop:
    beqz t3, .L_bclri_done
    .rept 25
    bclri  t0, a5, 1
    bclri  t1, a5, 1
    bclri  t2, a5, 1
    bclri  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_bclri_loop
.L_bclri_done:
    ret
