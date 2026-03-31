    .text

# --- CSRRW: rd=CSR; CSR=rs1 ---
# Dispatch: CSR → INT Pipe 1
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_csrrw
    .balign 4
test_csrrw:
    mv   t3, a0
    li  a5, 0
.L_csrrw_loop:
    beqz t3, .L_csrrw_done
    .rept 25
    csrrw  t0, fflags, a5
    csrrw  t1, fflags, a5
    csrrw  t2, fflags, a5
    csrrw  t4, fflags, a5
    .endr
    addi t3, t3, -1
    j    .L_csrrw_loop
.L_csrrw_done:
    ret
