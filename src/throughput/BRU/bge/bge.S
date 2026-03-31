    .text

# --- BGE: branch if rs1>=rs2 signed ---
# Dispatch: BRU → INT Pipe 1
# Expected throughput=1, latency=1
# 1 independent insns × .rept 100 = 100 insns/loop

    .global test_bge
    .balign 4
test_bge:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_bge_loop:
    beqz t3, .L_bge_done
    .rept 100
    bge  a6, a5, .+4
    .endr
    addi t3, t3, -1
    j    .L_bge_loop
.L_bge_done:
    ret
