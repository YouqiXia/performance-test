    .text

# --- LD↔MUL (L2) forwarding chain ---
# ld→mul→ld round-trip via random linked list (L2 hit)
# Construction: .rept 100, insn_per_iter=2
# t0 = chain register (pointer), t1 = 1 keeps value unchanged
    .global test_ld_mul
    .balign 4
test_ld_mul:
    mv   t3, a0
    mv   t0, a1          # t0 = chain head pointer
    li   t1, 1            # t1 = 1, mul identity
.L_ld_mul_loop:
    beqz t3, .L_ld_mul_done
    .rept 100
    ld   t0, 0(t0)
    mul  t0, t0, t1
    .endr
    addi t3, t3, -1
    j    .L_ld_mul_loop
.L_ld_mul_done:
    ret
