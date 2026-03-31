    .text

# --- BLTU: branch if rs1<rs2 unsigned ---
# Dispatch: BRU → INT Pipe 1
# Expected throughput=1, latency=1
# 1 independent insns × .rept 100 = 100 insns/loop

    .global test_bltu
    .balign 4
test_bltu:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_bltu_loop:
    beqz t3, .L_bltu_done
    .rept 100
    bltu  a5, a6, .+4
    .endr
    addi t3, t3, -1
    j    .L_bltu_loop
.L_bltu_done:
    ret
