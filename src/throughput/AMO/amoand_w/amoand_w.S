    .text

# --- AMOAND.W: Atomic AND W ---
# Dispatch: AMO → MEM Pipe (serialize)
# Expected throughput=—, latency=—
# 4 independent insns × .rept 5 = 20 insns/loop

    .global test_amoand_w
    .balign 4
test_amoand_w:
    mv   t3, a0
    li  a5, 0
.L_amoand_w_loop:
    beqz t3, .L_amoand_w_done
    .rept 5
    amoand.w  t0, a5, (a1)
    amoand.w  t1, a5, (a1)
    amoand.w  t2, a5, (a1)
    amoand.w  t4, a5, (a1)
    .endr
    addi t3, t3, -1
    j    .L_amoand_w_loop
.L_amoand_w_done:
    ret
