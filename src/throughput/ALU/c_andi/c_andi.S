    .text

# --- C.ANDI: rd'&imm ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_andi
    .balign 4
test_c_andi:
    mv   t3, a0
.L_c_andi_loop:
    beqz t3, .L_c_andi_done
    .rept 25
    c.andi  a2, 1
    c.andi  a3, 1
    c.andi  a4, 1
    c.andi  a5, 1
    .endr
    addi t3, t3, -1
    j    .L_c_andi_loop
.L_c_andi_done:
    ret
