    .text
    .global test_find_msb
    .balign 4
test_find_msb:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0            # s0 = nloop

    li   s1, 0x0000F000    # test value

.L_msb_outer:
    beqz s0, .L_msb_done
    mv   a2, s1            # restore value
    li   t1, -1            # pos = -1

.L_msb_inner:
    beqz a2, .L_msb_iter_done
    srli a2, a2, 1
    addi t1, t1, 1
    j    .L_msb_inner

.L_msb_iter_done:
    mv   a0, t1
    addi s0, s0, -1
    j    .L_msb_outer

.L_msb_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
