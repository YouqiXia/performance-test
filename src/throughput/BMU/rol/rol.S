    .text

# --- ROL: rotate left ---
# Dispatch: BMU → INT Pipe 3
# Expected throughput=1, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_rol
    .balign 4
test_rol:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_rol_loop:
    beqz t3, .L_rol_done
    .rept 25
    rol  t0, a5, a6
    rol  t1, a5, a6
    rol  t2, a5, a6
    rol  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_rol_loop
.L_rol_done:
    ret
