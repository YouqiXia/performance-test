    .text

# --- DIV ---
# DIV self-chain, t2=1 keeps value unchanged
# Construction: .rept 20, insn_per_iter=1
    .global test_div
    .balign 4
test_div:
    mv   t3, a0
    # Initialize registers
    li   t0, 42
    li   t2, 1
.L_div_loop:
    beqz t3, .L_div_done
    .rept 20
    div  t0, t0, t2
    .endr
    addi t3, t3, -1
    j    .L_div_loop
.L_div_done:
    ret
