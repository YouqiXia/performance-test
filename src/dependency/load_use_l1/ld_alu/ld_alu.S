    .text

# --- LD↔ALU (L1) forwarding chain ---
# ld→add→ld round-trip via self-loop pointer
# Construction: .rept 100, insn_per_iter=2
# t0 = chain register (pointer), add zero = identity
    .global test_ld_alu
    .balign 4
test_ld_alu:
    mv   t3, a0
    mv   t0, a1          # t0 = self-loop node pointer
.L_ld_alu_loop:
    beqz t3, .L_ld_alu_done
    .rept 100
    ld   t0, 0(t0)
    add  t0, t0, zero
    .endr
    addi t3, t3, -1
    j    .L_ld_alu_loop
.L_ld_alu_done:
    ret
