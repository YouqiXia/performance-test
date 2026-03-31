    .text

# --- C.LWSP: sext word from SP ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_lwsp
    .balign 4
test_c_lwsp:
    mv   t3, a0
    addi sp, sp, -256
.L_c_lwsp_loop:
    beqz t3, .L_c_lwsp_done
    .rept 25
    c.lwsp  t0, 0(sp)
    c.lwsp  t1, 4(sp)
    c.lwsp  t2, 8(sp)
    c.lwsp  t4, 12(sp)
    .endr
    addi t3, t3, -1
    j    .L_c_lwsp_loop
.L_c_lwsp_done:
    addi sp, sp, 256
    ret
