    .text

# --- CZERO.NEZ: rd=(rs2!=0)?0:rs1 ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_czero_nez
    .balign 4
test_czero_nez:
    mv   t3, a0
    li  a5, 42
    li  a6, 7
.L_czero_nez_loop:
    beqz t3, .L_czero_nez_done
    .rept 25
    czero.nez  t0, a5, a6
    czero.nez  t1, a5, a6
    czero.nez  t2, a5, a6
    czero.nez  t4, a5, a6
    .endr
    addi t3, t3, -1
    j    .L_czero_nez_loop
.L_czero_nez_done:
    ret
