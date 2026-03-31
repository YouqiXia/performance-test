    .text

# --- OR: rs1|rs2 ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_or
    .balign 4
test_or:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_or_loop:
    beqz t3, .L_or_done
    .rept 25
    or  t0, a5, a6
    or  t1, a5, a6
    or  t2, a5, a6
    or  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_or_loop
.L_or_done:
    ret
