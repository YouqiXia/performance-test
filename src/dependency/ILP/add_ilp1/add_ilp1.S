    .text

# --- ADD ILP=1 ---
# Single self-dependent chain: add t0,t0,t0
# Construction: .rept 100, insn_per_iter=1
    .global test_add_ilp1
    .balign 4
test_add_ilp1:
    mv   t3, a0
.L_add_ilp1_loop:
    beqz t3, .L_add_ilp1_done
    .rept 100
    add  t0, t0, t0
    .endr
    addi t3, t3, -1
    j    .L_add_ilp1_loop
.L_add_ilp1_done:
    ret
