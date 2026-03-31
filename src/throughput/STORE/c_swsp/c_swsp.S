    .text

# --- C.SWSP: store word SP ---
# Dispatch: STORE → MEM Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_swsp
    .balign 4
test_c_swsp:
    mv   t3, a0
    li  a5, 0
    addi sp, sp, -256
.L_c_swsp_loop:
    beqz t3, .L_c_swsp_done
    .rept 25
    c.swsp  a5, 0(sp)
    c.swsp  a5, 4(sp)
    c.swsp  a5, 8(sp)
    c.swsp  a5, 12(sp)
    .endr
    addi t3, t3, -1
    j    .L_c_swsp_loop
.L_c_swsp_done:
    addi sp, sp, 256
    ret
