    .text

# --- BINVI: rs1^(1<<shamt) ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_binvi
    .balign 4
test_binvi:
    mv   t3, a0
    li  a5, 42
.L_binvi_loop:
    beqz t3, .L_binvi_done
    .rept 25
    binvi  t0, a5, 1
    binvi  t1, a5, 1
    binvi  t2, a5, 1
    binvi  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_binvi_loop
.L_binvi_done:
    ret
