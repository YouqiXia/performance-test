    .text

# --- MUL ---
# MUL self-chain, t2=1 keeps value unchanged
# Construction: .rept 100, insn_per_iter=1
    .global test_mul
    .balign 4
test_mul:
    mv   t3, a0
    # Initialize registers
    li   t0, 42
    li   t2, 1
.L_mul_loop:
    beqz t3, .L_mul_done
    .rept 100
    mul  t0, t0, t2
    .endr
    addi t3, t3, -1
    j    .L_mul_loop
.L_mul_done:
    ret
