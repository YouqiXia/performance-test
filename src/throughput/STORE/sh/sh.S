    .text

# --- SH: Store half ---
# Dispatch: STORE → MEM Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sh
    .balign 4
test_sh:
    mv   t3, a0
    li  a5, 0
.L_sh_loop:
    beqz t3, .L_sh_done
    .rept 25
    sh  a5, 0(a1)
    sh  a5, 8(a1)
    sh  a5, 16(a1)
    sh  a5, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_sh_loop
.L_sh_done:
    ret
