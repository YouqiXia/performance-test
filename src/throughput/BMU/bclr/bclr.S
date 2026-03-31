    .text

# --- BCLR: rs1&~(1<<rs2) ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_bclr
    .balign 4
test_bclr:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_bclr_loop:
    beqz t3, .L_bclr_done
    .rept 25
    bclr  t0, a5, a6
    bclr  t1, a5, a6
    bclr  t2, a5, a6
    bclr  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_bclr_loop
.L_bclr_done:
    ret
