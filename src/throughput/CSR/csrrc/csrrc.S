    .text

# --- CSRRC: rd=CSR; CSR&=~rs1 ---
# Dispatch: CSR → INT Pipe 1
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_csrrc
    .balign 4
test_csrrc:
    mv   t3, a0
.L_csrrc_loop:
    beqz t3, .L_csrrc_done
    .rept 25
    csrrc  t0, fflags, x0
    csrrc  t1, fflags, x0
    csrrc  t2, fflags, x0
    csrrc  t4, fflags, x0
    .endr
    addi t3, t3, -1
    j    .L_csrrc_loop
.L_csrrc_done:
    ret
