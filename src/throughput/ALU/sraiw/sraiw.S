    .text

# --- SRAIW: sext32(rs1>>shamt arith) ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sraiw
    .balign 4
test_sraiw:
    mv   t3, a0
    li  a5, 42
.L_sraiw_loop:
    beqz t3, .L_sraiw_done
    .rept 25
    sraiw  t0, a5, 1
    sraiw  t1, a5, 1
    sraiw  t2, a5, 1
    sraiw  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_sraiw_loop
.L_sraiw_done:
    ret
