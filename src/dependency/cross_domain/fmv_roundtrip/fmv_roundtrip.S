    .text

# --- FMV INT↔FP roundtrip ---
# fmv.d.x→fmv.x.d round-trip (bitwise move, no conversion)
# Construction: .rept 100, insn_per_iter=2
# t0 = INT chain register, ft0 = FP intermediate
    .global test_fmv_roundtrip
    .balign 4
test_fmv_roundtrip:
    mv   t3, a0
    li   t0, 42
.L_fmv_roundtrip_loop:
    beqz t3, .L_fmv_roundtrip_done
    .rept 100
    fmv.d.x  ft0, t0
    fmv.x.d  t0, ft0
    .endr
    addi t3, t3, -1
    j    .L_fmv_roundtrip_loop
.L_fmv_roundtrip_done:
    ret
