    .text

# --- ADD ---
# ALU add self-chain, t1=0 keeps value unchanged
# Construction: .rept 100, insn_per_iter=1
    .global test_add
    .balign 4
test_add:
    mv   t3, a0
    # Initialize registers
    li   t1, 0
.L_add_loop:
    beqz t3, .L_add_done
    .rept 100
    add  t0, t0, t1
    .endr
    addi t3, t3, -1
    j    .L_add_loop
.L_add_done:
    ret
