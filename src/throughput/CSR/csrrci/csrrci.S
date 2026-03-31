    .text

# --- CSRRCI: rd=CSR; CSR&=~uimm ---
# Dispatch: CSR → INT Pipe 1
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_csrrci
    .balign 4
test_csrrci:
    mv   t3, a0
.L_csrrci_loop:
    beqz t3, .L_csrrci_done
    .rept 25
    csrrci  t0, fflags, 0
    csrrci  t1, fflags, 0
    csrrci  t2, fflags, 0
    csrrci  t4, fflags, 0
    .endr
    addi t3, t3, -1
    j    .L_csrrci_loop
.L_csrrci_done:
    ret
