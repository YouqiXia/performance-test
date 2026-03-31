    .text

# --- MUL↔DIV forwarding chain ---
# mul→div→mul→div round-trip
# Construction: .rept 20, insn_per_iter=2
# t0 = chain register, t1=1 (mul identity), t2=1 (div identity)
    .global test_mul_div
    .balign 4
test_mul_div:
    mv   t3, a0
    li   t1, 1
    li   t2, 1
.L_mul_div_loop:
    beqz t3, .L_mul_div_done
    .rept 20
    mul  t0, t0, t1
    div  t0, t0, t2
    .endr
    addi t3, t3, -1
    j    .L_mul_div_loop
.L_mul_div_done:
    ret
