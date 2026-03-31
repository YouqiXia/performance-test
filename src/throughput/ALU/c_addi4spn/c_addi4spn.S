    .text

# --- C.ADDI4SPN: rd=sp+imm ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_addi4spn
    .balign 4
test_c_addi4spn:
    mv   t3, a0
.L_c_addi4spn_loop:
    beqz t3, .L_c_addi4spn_done
    .rept 25
    c.addi4spn a2, sp, 16
    c.addi4spn a3, sp, 16
    c.addi4spn a4, sp, 16
    c.addi4spn a5, sp, 16
    .endr
    addi t3, t3, -1
    j    .L_c_addi4spn_loop
.L_c_addi4spn_done:
    ret
