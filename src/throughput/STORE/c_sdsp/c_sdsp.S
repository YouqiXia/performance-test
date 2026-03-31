    .text

# --- C.SDSP: store dword SP ---
# Dispatch: STORE → MEM Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_sdsp
    .balign 4
test_c_sdsp:
    mv   t3, a0
    li  a5, 0
    addi sp, sp, -256
.L_c_sdsp_loop:
    beqz t3, .L_c_sdsp_done
    .rept 25
    c.sdsp  a5, 0(sp)
    c.sdsp  a5, 8(sp)
    c.sdsp  a5, 16(sp)
    c.sdsp  a5, 24(sp)
    .endr
    addi t3, t3, -1
    j    .L_c_sdsp_loop
.L_c_sdsp_done:
    addi sp, sp, 256
    ret
