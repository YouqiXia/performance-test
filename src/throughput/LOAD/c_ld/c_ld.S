    .text

# --- C.LD: dword ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_ld
    .balign 4
test_c_ld:
    mv   t3, a0
    addi sp, sp, -16
    sd   s0, 0(sp)
    mv   s0, a1
.L_c_ld_loop:
    beqz t3, .L_c_ld_done
    .rept 25
    c.ld  a2, 0(s0)
    c.ld  a3, 8(s0)
    c.ld  a4, 16(s0)
    c.ld  a5, 24(s0)
    .endr
    addi t3, t3, -1
    j    .L_c_ld_loop
.L_c_ld_done:
    ld   s0, 0(sp)
    addi sp, sp, 16
    ret
