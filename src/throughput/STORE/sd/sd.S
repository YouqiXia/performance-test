    .text

# --- SD: Store dword ---
# Dispatch: STORE → MEM Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sd
    .balign 4
test_sd:
    mv   t3, a0
    li  a5, 0
.L_sd_loop:
    beqz t3, .L_sd_done
    .rept 25
    sd  a5, 0(a1)
    sd  a5, 8(a1)
    sd  a5, 16(a1)
    sd  a5, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_sd_loop
.L_sd_done:
    ret
