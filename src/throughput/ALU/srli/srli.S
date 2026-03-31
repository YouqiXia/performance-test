    .text

# --- SRLI: rs1>>shamt log ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_srli
    .balign 4
test_srli:
    mv   t3, a0
    li  a5, 42
.L_srli_loop:
    beqz t3, .L_srli_done
    .rept 25
    srli  t0, a5, 1
    srli  t1, a5, 1
    srli  t2, a5, 1
    srli  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_srli_loop
.L_srli_done:
    ret
