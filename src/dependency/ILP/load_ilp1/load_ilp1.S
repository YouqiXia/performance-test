    .text

# --- LOAD ILP=1 ---
# Single self-loop pointer chase: ld t0, 0(t0)
# Construction: .rept 100, insn_per_iter=1
# a0 = nloop, a1 = self-loop node pointer
    .global test_load_ilp1
    .balign 4
test_load_ilp1:
    mv   t3, a0
    mv   t0, a1
.L_load_ilp1_loop:
    beqz t3, .L_load_ilp1_done
    .rept 100
    ld   t0, 0(t0)
    .endr
    addi t3, t3, -1
    j    .L_load_ilp1_loop
.L_load_ilp1_done:
    ret
