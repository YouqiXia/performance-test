    .text
    .global test_str_cpy
    .balign 4
test_str_cpy:
    addi sp, sp, -8
    sd   s0, 0(sp)
    mv   s0, a0

.L_scp_outer:
    beqz s0, .L_scp_done
    la   a1, .L_scp_src
    la   a0, .L_scp_dst

.L_scp_loop:
    lb   t3, 0(a1)
    sb   t3, 0(a0)
    addi a1, a1, 1
    addi a0, a0, 1
    bnez t3, .L_scp_loop

    addi s0, s0, -1
    j    .L_scp_outer

.L_scp_done:
    ld   s0, 0(sp)
    addi sp, sp, 8
    ret

.section .data
.L_scp_src:
    .rept 1023
    .byte 'a'
    .endr
    .byte 0
.L_scp_dst:
    .space 1024
