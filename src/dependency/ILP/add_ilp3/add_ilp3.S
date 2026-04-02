    .text

# --- ADD ILP=3 ---
# Three independent self-dependent chains: t0, t1, t2
# Construction: .rept 100, insn_per_iter=3
    .global test_add_ilp3
    .balign 4
test_add_ilp3:
    mv   t3, a0
.L_add_ilp3_loop:
    beqz t3, .L_add_ilp3_done
    .rept 100
    add  t0, t0, t0
    add  t1, t1, t1
    add  t2, t2, t2
    .endr
    addi t3, t3, -1
    j    .L_add_ilp3_loop
.L_add_ilp3_done:
    ret
