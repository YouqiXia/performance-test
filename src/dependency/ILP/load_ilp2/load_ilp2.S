    .text

# --- LOAD ILP=2 ---
# Two independent self-loop pointer chases: t0, t1
# Construction: .rept 100, insn_per_iter=2
# a0 = nloop, a1 = node0, a2 = node1
    .global test_load_ilp2
    .balign 4
test_load_ilp2:
    mv   t3, a0
    mv   t0, a1
    mv   t1, a2
.L_load_ilp2_loop:
    beqz t3, .L_load_ilp2_done
    .rept 100
    ld   t0, 0(t0)
    ld   t1, 0(t1)
    .endr
    addi t3, t3, -1
    j    .L_load_ilp2_loop
.L_load_ilp2_done:
    ret
