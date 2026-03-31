    .text

# --- C.LW: sext word ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_lw
    .balign 4
test_c_lw:
    mv   t3, a0
    addi sp, sp, -16
    sd   s0, 0(sp)
    mv   s0, a1
.L_c_lw_loop:
    beqz t3, .L_c_lw_done
    .rept 25
    c.lw  a2, 0(s0)
    c.lw  a3, 4(s0)
    c.lw  a4, 8(s0)
    c.lw  a5, 12(s0)
    .endr
    addi t3, t3, -1
    j    .L_c_lw_loop
.L_c_lw_done:
    ld   s0, 0(sp)
    addi sp, sp, 16
    ret
