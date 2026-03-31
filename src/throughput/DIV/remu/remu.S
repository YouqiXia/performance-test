    .text

# --- REMU: rs1%rs2 unsigned ---
# Dispatch: DIV → INT Pipe 0
# Expected throughput=1/17, latency=17-18
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_remu
    .balign 4
test_remu:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_remu_loop:
    beqz t3, .L_remu_done
    .rept 5
    remu  t0, a5, a6
    remu  t1, a5, a6
    remu  t2, a5, a6
    remu  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_remu_loop
.L_remu_done:
    ret
