    .text
    .global test_bitcount
    .balign 4
test_bitcount:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0            # s0 = nloop

    li   s1, 0xF0F0F0F0F0F0F0F0  # test value

.L_bitcount_outer:
    beqz s0, .L_bitcount_done
    mv   a2, s1            # restore value
    li   a0, 0             # count = 0

.L_bitcount_inner:
    beqz a2, .L_bitcount_iter_done
    andi t1, a2, 1
    add  a0, a0, t1
    srli a2, a2, 1
    j    .L_bitcount_inner

.L_bitcount_iter_done:
    addi s0, s0, -1
    j    .L_bitcount_outer

.L_bitcount_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
