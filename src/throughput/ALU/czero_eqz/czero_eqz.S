    .text

# --- CZERO.EQZ: rd=(rs2==0)?0:rs1 ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_czero_eqz
    .balign 4
test_czero_eqz:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_czero_eqz_loop:
    beqz t3, .L_czero_eqz_done
    .rept 25
    czero.eqz  t0, a5, a6
    czero.eqz  t1, a5, a6
    czero.eqz  t2, a5, a6
    czero.eqz  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_czero_eqz_loop
.L_czero_eqz_done:
    ret
