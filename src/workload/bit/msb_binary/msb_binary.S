    .text
    .global test_msb_binary
    .balign 4
test_msb_binary:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0            # s0 = nloop

    li   s1, 0x0000F000    # test value

.L_msbb_outer:
    beqz s0, .L_msbb_done
    mv   a0, s1            # restore value
    li   t1, 0             # pos = 0

    # Check high 16 bits
    li   t2, 0xFFFF0000
    and  t3, a0, t2
    beqz t3, .L_msbb_check8
    srli a0, a0, 16
    addi t1, t1, 16

.L_msbb_check8:
    li   t2, 0x0000FF00
    and  t3, a0, t2
    beqz t3, .L_msbb_check4
    srli a0, a0, 8
    addi t1, t1, 8

.L_msbb_check4:
    li   t2, 0x000000F0
    and  t3, a0, t2
    beqz t3, .L_msbb_check2
    srli a0, a0, 4
    addi t1, t1, 4

.L_msbb_check2:
    li   t2, 0x000C
    and  t3, a0, t2
    beqz t3, .L_msbb_check1
    srli a0, a0, 2
    addi t1, t1, 2

.L_msbb_check1:
    li   t2, 0x0002
    and  t3, a0, t2
    beqz t3, .L_msbb_iter_done
    addi t1, t1, 1

.L_msbb_iter_done:
    mv   a0, t1
    addi s0, s0, -1
    j    .L_msbb_outer

.L_msbb_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
