    .text

# --- C.SLLI: rd<<shamt ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_slli
    .balign 4
test_c_slli:
    mv   t3, a0
.L_c_slli_loop:
    beqz t3, .L_c_slli_done
    .rept 25
    c.slli  t0, 1
    c.slli  t1, 1
    c.slli  t2, 1
    c.slli  t4, 1
    .endr
    addi t3, t3, -1
    j    .L_c_slli_loop
.L_c_slli_done:
    ret
