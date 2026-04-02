    .text

# --- LOAD ILP=4 ---
# Four independent self-loop pointer chases: t0, t1, t2, t4
# Construction: .rept 100, insn_per_iter=4
# a0 = nloop, a1 = node0, a2 = node1, a3 = node2, a4 = node3
    .global test_load_ilp4
    .balign 4
test_load_ilp4:
    mv   t3, a0
    mv   t0, a1
    mv   t1, a2
    mv   t2, a3
    mv   t4, a4
.L_load_ilp4_loop:
    beqz t3, .L_load_ilp4_done
    .rept 100
    ld   t0, 0(t0)
    ld   t1, 0(t1)
    ld   t2, 0(t2)
    ld   t4, 0(t4)
    .endr
    addi t3, t3, -1
    j    .L_load_ilp4_loop
.L_load_ilp4_done:
    ret
