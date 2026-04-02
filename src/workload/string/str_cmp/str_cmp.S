    .text
    .global test_str_cmp
    .balign 4
test_str_cmp:
    addi sp, sp, -8
    sd   s0, 0(sp)
    mv   s0, a0

.L_sc_outer:
    beqz s0, .L_sc_done
    la   a0, .L_sc_str2
    la   a1, .L_sc_str1

.L_sc_loop:
    lb   t1, 0(a0)
    lb   t2, 0(a1)
    beqz t1, .L_sc_cmp_done
    bne  t1, t2, .L_sc_cmp_done
    addi a0, a0, 1
    addi a1, a1, 1
    j    .L_sc_loop

.L_sc_cmp_done:
    sub  t6, t1, t2
    addi s0, s0, -1
    j    .L_sc_outer

.L_sc_done:
    ld   s0, 0(sp)
    addi sp, sp, 8
    ret

.section .data
.align 3
.L_sc_str1:
    .ascii "Hello, RISC-V Assembly World! This is a test string for strcmp performance benchmarking. "
    .ascii "The quick brown fox jumps over the lazy dog. "
    .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    .byte 0
.align 3
.L_sc_str2:
    .ascii "Hello, RISC-V Assembly World! This is a test string for strcmp performance benchmarking. "
    .ascii "The quick brown fox jumps over the lazy dog. "
    .ascii "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456788"
    .byte 0
