    .text

# --- SLLI: rs1<<shamt ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_slli
    .balign 4
test_slli:
    mv   t3, a0
    li  a5, 42
.L_slli_loop:
    beqz t3, .L_slli_done
    .rept 25
    slli  t0, a5, 1
    slli  t1, a5, 1
    slli  t2, a5, 1
    slli  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_slli_loop
.L_slli_done:
    ret
