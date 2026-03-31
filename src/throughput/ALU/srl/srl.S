    .text

# --- SRL: rs1>>rs2[5:0] log ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_srl
    .balign 4
test_srl:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_srl_loop:
    beqz t3, .L_srl_done
    .rept 25
    srl  t0, a5, a6
    srl  t1, a5, a6
    srl  t2, a5, a6
    srl  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_srl_loop
.L_srl_done:
    ret
