    .text

# --- ANDI: rs1&imm ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_andi
    .balign 4
test_andi:
    mv   t3, a0
    li  a5, 42
.L_andi_loop:
    beqz t3, .L_andi_done
    .rept 25
    andi  t0, a5, 1
    andi  t1, a5, 1
    andi  t2, a5, 1
    andi  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_andi_loop
.L_andi_done:
    ret
