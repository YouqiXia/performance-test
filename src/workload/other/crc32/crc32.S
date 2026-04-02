    .text
    .global test_crc32
    .balign 4
test_crc32:
    addi sp, sp, -24
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    sd   s2, 16(sp)
    mv   s0, a0

    la   s1, .L_crc_data
    la   s2, .L_crc_table

.L_crc_outer:
    beqz s0, .L_crc_done
    mv   t0, s1            # data ptr
    li   t1, 0             # index
    li   a0, 0             # crc = 0

.L_crc_inner:
    li   t6, 16
    bge  t1, t6, .L_crc_iter_done
    add  t2, t0, t1
    lb   t3, 0(t2)
    andi t3, t3, 0x0F
    slli t4, t3, 2
    add  t4, s2, t4
    lw   t5, 0(t4)
    xor  a0, a0, t5
    addi t1, t1, 1
    j    .L_crc_inner

.L_crc_iter_done:
    addi s0, s0, -1
    j    .L_crc_outer

.L_crc_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    ld   s2, 16(sp)
    addi sp, sp, 24
    ret

.section .data
.L_crc_data:
    .byte 0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07
    .byte 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F
.align 4
.L_crc_table:
    .word 0x0000, 0x77073096, 0xEE0E612C, 0x990951BA
    .word 0x076DC419, 0x706AF48F, 0xE963A535, 0x9E6495A3
    .word 0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988
    .word 0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91
