    .text

# --- BGEU: branch if rs1>=rs2 unsigned ---
# Dispatch: BRU → INT Pipe 1
# Expected throughput=1, latency=1
# 1 independent insns × .rept 100 = 100 insns/loop

    .global test_bgeu
    .balign 4
test_bgeu:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_bgeu_loop:
    beqz t3, .L_bgeu_done
    .rept 100
    bgeu  a6, a5, .+4
    .endr
    addi t3, t3, -1
    j    .L_bgeu_loop
.L_bgeu_done:
    ret
