    .text

# --- ADDI: rs1+imm ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_addi
    .balign 4
test_addi:
    mv   t3, a0
    li  a5, 42
.L_addi_loop:
    beqz t3, .L_addi_done
    .rept 25
    addi  t0, a5, 1
    addi  t1, a5, 1
    addi  t2, a5, 1
    addi  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_addi_loop
.L_addi_done:
    ret
