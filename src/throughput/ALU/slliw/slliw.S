    .text

# --- SLLIW: sext32(rs1<<shamt) ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_slliw
    .balign 4
test_slliw:
    mv   t3, a0
    li  a5, 42
.L_slliw_loop:
    beqz t3, .L_slliw_done
    .rept 25
    slliw  t0, a5, 1
    slliw  t1, a5, 1
    slliw  t2, a5, 1
    slliw  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_slliw_loop
.L_slliw_done:
    ret
