    .text

# --- CSRRS: rd=CSR; CSR|=rs1 ---
# Dispatch: CSR → INT Pipe 1
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_csrrs
    .balign 4
test_csrrs:
    mv   t3, a0
.L_csrrs_loop:
    beqz t3, .L_csrrs_done
    .rept 25
    csrrs  t0, fflags, x0
    csrrs  t1, fflags, x0
    csrrs  t2, fflags, x0
    csrrs  t4, fflags, x0
    .endr
    addi t3, t3, -1
    j    .L_csrrs_loop
.L_csrrs_done:
    ret
