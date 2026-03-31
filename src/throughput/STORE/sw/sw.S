    .text

# --- SW: Store word ---
# Dispatch: STORE → MEM Pipe 0
# Expected throughput=1, latency=2
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_sw
    .balign 4
test_sw:
    mv   t3, a0
    li  a5, 0
.L_sw_loop:
    beqz t3, .L_sw_done
    .rept 25
    sw  a5, 0(a1)
    sw  a5, 8(a1)
    sw  a5, 16(a1)
    sw  a5, 24(a1)
    .endr
    addi t3, t3, -1
    j    .L_sw_loop
.L_sw_done:
    ret
