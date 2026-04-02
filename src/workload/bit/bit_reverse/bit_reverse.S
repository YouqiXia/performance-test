    .text
    .global test_bit_reverse
    .balign 4
test_bit_reverse:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0            # s0 = nloop

    li   s1, 0x12345678    # test value

.L_br_outer:
    beqz s0, .L_br_done
    mv   a0, s1            # restore value
    li   t1, 0             # i = 0
    li   t2, 0             # result = 0

.L_br_inner:
    li   t4, 32
    bge  t1, t4, .L_br_iter_done
    slli t2, t2, 1         # result <<= 1
    andi t3, a0, 1         # x & 1
    or   t2, t2, t3        # result |= (x & 1)
    srli a0, a0, 1         # x >>= 1
    addi t1, t1, 1
    j    .L_br_inner

.L_br_iter_done:
    mv   a0, t2
    addi s0, s0, -1
    j    .L_br_outer

.L_br_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
