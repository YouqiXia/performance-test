    .text

# --- ADD ILP=4 ---
# Four independent self-dependent chains: t0, t1, t2, t4
# Construction: .rept 100, insn_per_iter=4
    .global test_add_ilp4
    .balign 4
test_add_ilp4:
    mv   t3, a0
.L_add_ilp4_loop:
    beqz t3, .L_add_ilp4_done
    .rept 100
    add  t0, t0, t0
    add  t1, t1, t1
    add  t2, t2, t2
    add  t4, t4, t4
    .endr
    addi t3, t3, -1
    j    .L_add_ilp4_loop
.L_add_ilp4_done:
    ret
