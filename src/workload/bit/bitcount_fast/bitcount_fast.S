    .text
    .global test_bitcount_fast
    .balign 4
test_bitcount_fast:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0            # s0 = nloop

    li   s1, 0xF0F0F0F0F0F0F0F0  # test value

.L_bcf_outer:
    beqz s0, .L_bcf_done
    mv   a2, s1            # restore value
    li   t1, 0             # count = 0

.L_bcf_inner:
    beqz a2, .L_bcf_iter_done
    addi t2, a2, -1
    and  a2, a2, t2        # x &= (x-1)
    addi t1, t1, 1
    j    .L_bcf_inner

.L_bcf_iter_done:
    mv   a0, t1
    addi s0, s0, -1
    j    .L_bcf_outer

.L_bcf_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret
