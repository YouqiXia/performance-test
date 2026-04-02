    .text
    .global test_str_len
    .balign 4
test_str_len:
    addi sp, sp, -8
    sd   s0, 0(sp)
    mv   s0, a0

.L_sl_outer:
    beqz s0, .L_sl_done
    la   t2, .L_sl_str
    li   t3, 0

.L_sl_loop:
    lb   t4, 0(t2)
    beqz t4, .L_sl_iter_done
    addi t2, t2, 1
    addi t3, t3, 1
    j    .L_sl_loop

.L_sl_iter_done:
    addi s0, s0, -1
    j    .L_sl_outer

.L_sl_done:
    ld   s0, 0(sp)
    addi sp, sp, 8
    ret

.section .data
.L_sl_str:
    .rept 1023
    .byte 'a'
    .endr
    .byte 0
