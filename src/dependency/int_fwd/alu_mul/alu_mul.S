    .text

# --- ALU↔MUL forwarding chain ---
# add→mul→add→mul round-trip
# Construction: .rept 100, insn_per_iter=2
# t0 = chain register, t1=0 (add identity), t2=1 (mul identity)
    .global test_alu_mul
    .balign 4
test_alu_mul:
    mv   t3, a0
    li   t1, 0
    li   t2, 1
.L_alu_mul_loop:
    beqz t3, .L_alu_mul_done
    .rept 100
    add  t0, t0, t1
    mul  t0, t0, t2
    .endr
    addi t3, t3, -1
    j    .L_alu_mul_loop
.L_alu_mul_done:
    ret
