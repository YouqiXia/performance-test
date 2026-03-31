    .text

# --- LD↔DIV (L1) forwarding chain ---
# ld→div→ld round-trip via self-loop pointer
# Construction: .rept 20, insn_per_iter=2
# t0 = chain register (pointer), t1=1 (div identity)
# .rept=20 because DIV is very slow
    .global test_ld_div
    .balign 4
test_ld_div:
    mv   t3, a0
    mv   t0, a1          # t0 = self-loop node pointer
    li   t1, 1
.L_ld_div_loop:
    beqz t3, .L_ld_div_done
    .rept 20
    ld   t0, 0(t0)
    div  t0, t0, t1
    .endr
    addi t3, t3, -1
    j    .L_ld_div_loop
.L_ld_div_done:
    ret
