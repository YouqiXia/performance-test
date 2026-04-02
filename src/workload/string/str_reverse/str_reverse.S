    .text
    .global test_str_reverse
    .balign 4
test_str_reverse:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    mv   s0, a0
    li   s1, 0

.L_sr_outer:
    beqz s0, .L_sr_done
    la   a0, .L_sr_str

    # Calculate length
    mv   a1, a0
    li   a2, 0
.L_sr_len:
    lb   t0, 0(a1)
    beqz t0, .L_sr_len_done
    addi a1, a1, 1
    addi a2, a2, 1
    j    .L_sr_len
.L_sr_len_done:

    addi a3, a2, -1        # j = n-1
    li   t1, 0             # i = 0
    srli t2, a2, 1         # n/2

.L_sr_rev:
    bge  t1, t2, .L_sr_rev_done
    add  t3, a0, t1
    lb   t4, 0(t3)
    add  t5, a0, a3
    lb   t6, 0(t5)
    sb   t6, 0(t3)
    sb   t4, 0(t5)
    addi t1, t1, 1
    addi a3, a3, -1
    j    .L_sr_rev

.L_sr_rev_done:
    lb   t0, 0(a0)
    add  s1, s1, t0
    addi s0, s0, -1
    j    .L_sr_outer

.L_sr_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    addi sp, sp, 16
    ret

.section .data
.align 4
.L_sr_str:
    .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    .byte 0
