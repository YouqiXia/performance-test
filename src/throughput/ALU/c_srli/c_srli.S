    .text

# --- C.SRLI: rd'>>shamt log ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_srli
    .balign 4
test_c_srli:
    mv   t3, a0
.L_c_srli_loop:
    beqz t3, .L_c_srli_done
    .rept 25
    c.srli  a2, 1
    c.srli  a3, 1
    c.srli  a4, 1
    c.srli  a5, 1
    .endr
    addi t3, t3, -1
    j    .L_c_srli_loop
.L_c_srli_done:
    ret
