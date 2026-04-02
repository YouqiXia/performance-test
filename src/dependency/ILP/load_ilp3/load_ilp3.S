    .text

# --- LOAD ILP=3 ---
# Three independent self-loop pointer chases: t0, t1, t2
# Construction: .rept 100, insn_per_iter=3
# a0 = nloop, a1 = node0, a2 = node1, a3 = node2
    .global test_load_ilp3
    .balign 4
test_load_ilp3:
    mv   t3, a0
    mv   t0, a1
    mv   t1, a2
    mv   t2, a3
.L_load_ilp3_loop:
    beqz t3, .L_load_ilp3_done
    .rept 100
    ld   t0, 0(t0)
    ld   t1, 0(t1)
    ld   t2, 0(t2)
    .endr
    addi t3, t3, -1
    j    .L_load_ilp3_loop
.L_load_ilp3_done:
    ret
