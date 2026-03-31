    .text

# --- FCVTMOD.W.D: FP64→INT32 JS semantics ---
# Dispatch: FCVT.F2I → FP Pipe 1
# Expected throughput=1, latency=2 (FU) / 3 (effective, cross-domain)
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_fcvtmod_w_d
    .balign 4
test_fcvtmod_w_d:
    mv   t3, a0
    # Initialize FP source regs to 1.0 (normal positive)
    li   t5, 0x3FF0000000000000
    fmv.d.x ft8, t5
    fmv.d.x ft9, t5
    fmv.d.x ft10, t5
.L_fcvtmod_w_d_loop:
    beqz t3, .L_fcvtmod_w_d_done
    .rept 25
    fcvtmod.w.d  t0, ft8, rtz
    fcvtmod.w.d  t1, ft8, rtz
    fcvtmod.w.d  t2, ft8, rtz
    fcvtmod.w.d  t4, ft8, rtz
    .endr
    addi t3, t3, -1
    j    .L_fcvtmod_w_d_loop
.L_fcvtmod_w_d_done:
    ret
