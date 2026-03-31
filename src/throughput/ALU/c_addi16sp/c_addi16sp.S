    .text

# --- C.ADDI16SP: sp=sp+imm*16 ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 2 independent insns × .rept 50 = 100 insns/loop

    .global test_c_addi16sp
    .balign 4
test_c_addi16sp:
    mv   t3, a0
.L_c_addi16sp_loop:
    beqz t3, .L_c_addi16sp_done
    .rept 50
    c.addi16sp sp, 16
    c.addi16sp sp, -16
    .endr
    addi t3, t3, -1
    j    .L_c_addi16sp_loop
.L_c_addi16sp_done:
    ret
