    .text

# --- FCVT INT↔FP roundtrip ---
# fcvt.d.w→fcvt.w.d round-trip (INT→FP→INT)
# Construction: .rept 100, insn_per_iter=2
# t0 = INT chain register, ft0 = FP intermediate
    .global test_fcvt_roundtrip
    .balign 4
test_fcvt_roundtrip:
    mv   t3, a0
    li   t0, 42
.L_fcvt_roundtrip_loop:
    beqz t3, .L_fcvt_roundtrip_done
    .rept 100
    fcvt.d.w  ft0, t0
    fcvt.w.d  t0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fcvt_roundtrip_loop
.L_fcvt_roundtrip_done:
    ret
