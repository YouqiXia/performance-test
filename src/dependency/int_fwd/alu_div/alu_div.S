    .text

# --- ALU↔DIV forwarding chain ---
# add→div→add→div round-trip
# Construction: .rept 20, insn_per_iter=2
# t0 = chain register, t1=0 (add identity), t2=1 (div identity)
    .global test_alu_div
    .balign 4
test_alu_div:
    mv   t3, a0
    li   t1, 0
    li   t2, 1
.L_alu_div_loop:
    beqz t3, .L_alu_div_done
    .rept 20
    add  t0, t0, t1
    div  t0, t0, t2
    .endr
    addi t3, t3, -1
    j    .L_alu_div_loop
.L_alu_div_done:
    ret
