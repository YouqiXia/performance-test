    .text

# --- CSRRSI: rd=CSR; CSR|=uimm ---
# Dispatch: CSR → INT Pipe 1
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_csrrsi
    .balign 4
test_csrrsi:
    mv   t3, a0
.L_csrrsi_loop:
    beqz t3, .L_csrrsi_done
    .rept 25
    csrrsi  t0, fflags, 0
    csrrsi  t1, fflags, 0
    csrrsi  t2, fflags, 0
    csrrsi  t4, fflags, 0
    .endr
    addi t3, t3, -1
    j    .L_csrrsi_loop
.L_csrrsi_done:
    ret
