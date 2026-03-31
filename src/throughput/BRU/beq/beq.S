    .text

# --- BEQ: branch if rs1==rs2 ---
# Dispatch: BRU → INT Pipe 1
# Expected throughput=1, latency=1
# 1 independent insns × .rept 100 = 100 insns/loop

    .global test_beq
    .balign 4
test_beq:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_beq_loop:
    beqz t3, .L_beq_done
    .rept 100
    beq  a5, a6, .+4
    .endr
    addi t3, t3, -1
    j    .L_beq_loop
.L_beq_done:
    ret
