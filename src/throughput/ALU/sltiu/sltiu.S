    .text

# --- SLTIU: (rs1<imm)?1:0 unsigned ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sltiu
    .balign 4
test_sltiu:
    mv   t3, a0
    li  a5, 42
.L_sltiu_loop:
    beqz t3, .L_sltiu_done
    .rept 25
    sltiu  t0, a5, 1
    sltiu  t1, a5, 1
    sltiu  t2, a5, 1
    sltiu  t4, a5, 1
    .endr
    addi t3, t3, -1
    j    .L_sltiu_loop
.L_sltiu_done:
    ret
