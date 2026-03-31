    .text

# --- C.ADDI: rd=rd+imm ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_addi
    .balign 4
test_c_addi:
    mv   t3, a0
.L_c_addi_loop:
    beqz t3, .L_c_addi_done
    .rept 25
    c.addi  t0, 1
    c.addi  t1, 1
    c.addi  t2, 1
    c.addi  t4, 1
    .endr
    addi t3, t3, -1
    j    .L_c_addi_loop
.L_c_addi_done:
    ret
