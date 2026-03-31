    .text

# --- CSRRWI: rd=CSR; CSR=uimm ---
# Dispatch: CSR → INT Pipe 1
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_csrrwi
    .balign 4
test_csrrwi:
    mv   t3, a0
.L_csrrwi_loop:
    beqz t3, .L_csrrwi_done
    .rept 25
    csrrwi  t0, fflags, 0
    csrrwi  t1, fflags, 0
    csrrwi  t2, fflags, 0
    csrrwi  t4, fflags, 0
    .endr
    addi t3, t3, -1
    j    .L_csrrwi_loop
.L_csrrwi_done:
    ret
