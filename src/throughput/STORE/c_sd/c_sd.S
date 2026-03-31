    .text

# --- C.SD: store dword ---
# Dispatch: STORE → MEM Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_sd
    .balign 4
test_c_sd:
    mv   t3, a0
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a1
    li   s1, 0
.L_c_sd_loop:
    beqz t3, .L_c_sd_done
    .rept 25
    c.sd  s1, 0(s0)
    c.sd  s1, 8(s0)
    c.sd  s1, 16(s0)
    c.sd  s1, 24(s0)
    .endr
    addi t3, t3, -1
    j    .L_c_sd_loop
.L_c_sd_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
