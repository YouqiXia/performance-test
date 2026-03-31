    .text

# --- SB: Store byte ---
# Dispatch: STORE → MEM Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sb
    .balign 4
test_sb:
    mv   t3, a0
    li  a5, 0
.L_sb_loop:
    beqz t3, .L_sb_done
    .rept 25
    sb  a5, 0(a1)
    sb  a5, 8(a1)
    sb  a5, 16(a1)
    sb  a5, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_sb_loop
.L_sb_done:
    ret
