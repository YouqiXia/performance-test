    .text

# --- C.LH: sext half ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_lh
    .balign 4
test_c_lh:
    mv   t3, a0
    addi sp, sp, -16
    sd   s0, 0(sp)
    mv   s0, a1
.L_c_lh_loop:
    beqz t3, .L_c_lh_done
    .rept 25
    c.lh  a2, 0(s0)
    c.lh  a3, 2(s0)
    c.lh  a4, 0(s0)
    c.lh  a5, 2(s0)
    .endr
    addi t3, t3, -1
    j    .L_c_lh_loop
.L_c_lh_done:
    ld   s0, 0(sp)
    addi sp, sp, 16
    ret
