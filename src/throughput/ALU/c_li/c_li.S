    .text

# --- C.LI: rd=sext(imm) ---
# Dispatch: ALU → INT Pipe 0/1/2/3
# Expected throughput=4, latency=1
# 4 independent insns × .rept 25 = 100 insns/loop

    .global test_c_li
    .balign 4
test_c_li:
    mv   t3, a0
.L_c_li_loop:
    beqz t3, .L_c_li_done
    .rept 25
    c.li  t0, 1
    c.li  t1, 1
    c.li  t2, 1
    c.li  t4, 1
    .endr
    addi t3, t3, -1
    j    .L_c_li_loop
.L_c_li_done:
    ret
