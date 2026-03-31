    .text

# --- SRLIW: sext32(rs1>>shamt log) ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_srliw
    .balign 4
test_srliw:
    mv   t3, a0
    li  a5, 42
.L_srliw_loop:
    beqz t3, .L_srliw_done
    .rept 25
    srliw  t0, a5, 1
    srliw  t1, a5, 1
    srliw  t2, a5, 1
    srliw  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_srliw_loop
.L_srliw_done:
    ret
