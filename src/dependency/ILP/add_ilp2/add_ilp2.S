    .text

# --- ADD ILP=2 ---
# Two independent self-dependent chains: t0, t1
# Construction: .rept 100, insn_per_iter=2
    .global test_add_ilp2
    .balign 4
test_add_ilp2:
    mv   t3, a0
.L_add_ilp2_loop:
    beqz t3, .L_add_ilp2_done
    .rept 100
    add  t0, t0, t0
    add  t1, t1, t1
    .endr
    addi t3, t3, -1
    j    .L_add_ilp2_loop
.L_add_ilp2_done:
    ret
