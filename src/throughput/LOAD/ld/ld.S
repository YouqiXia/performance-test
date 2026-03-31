    .text

# --- LD: dword ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_ld
    .balign 4
test_ld:
    mv   t3, a0
.L_ld_loop:
    beqz t3, .L_ld_done
    .rept 25
    ld  t0, 0(a1)
    ld  t1, 8(a1)
    ld  t2, 16(a1)
    ld  t4, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_ld_loop
.L_ld_done:
    ret
