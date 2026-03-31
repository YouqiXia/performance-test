    .text

# --- C.NOT: bitwise NOT ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_not
    .balign 4
test_c_not:
    mv   t3, a0
.L_c_not_loop:
    beqz t3, .L_c_not_done
    .rept 25
    c.not  a2
    c.not  a3
    c.not  a4
    c.not  a5
    .endr
    addi t3, t3, -1
    j    .L_c_not_loop
.L_c_not_done:
    ret
