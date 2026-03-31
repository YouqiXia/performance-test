    .text

# --- C.LDSP: dword from SP ---
# Dispatch: LOAD → MEM Pipe 0/1
# Expected throughput=2, latency=2 (L1 hit) / 5 (L2 hit)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_ldsp
    .balign 4
test_c_ldsp:
    mv   t3, a0
    addi sp, sp, -256
.L_c_ldsp_loop:
    beqz t3, .L_c_ldsp_done
    .rept 25
    c.ldsp  t0, 0(sp)
    c.ldsp  t1, 8(sp)
    c.ldsp  t2, 16(sp)
    c.ldsp  t4, 24(sp)
    .endr
    addi t3, t3, -1
    j    .L_c_ldsp_loop
.L_c_ldsp_done:
    addi sp, sp, 256
    ret
