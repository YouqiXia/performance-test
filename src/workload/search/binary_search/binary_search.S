    .text
    .global test_binary_search
    .balign 4
test_binary_search:
    addi sp, sp, -8
    sd   s0, 0(sp)
    mv   s0, a0

.L_bs_outer:
    beqz s0, .L_bs_done
    la   t0, .L_bs_array
    li   t1, 0             # left
    li   t2, 9             # right
    li   a2, 42            # target

.L_bs_search:
    bgt  t1, t2, .L_bs_found
    sub  t3, t2, t1
    srli t3, t3, 1
    add  t3, t1, t3        # mid
    slli t4, t3, 2
    add  t4, t0, t4
    lw   t5, 0(t4)         # arr[mid]
    beq  t5, a2, .L_bs_found
    blt  t5, a2, .L_bs_right
    addi t2, t3, -1
    j    .L_bs_check
.L_bs_right:
    addi t1, t3, 1
.L_bs_check:
    ble  t1, t2, .L_bs_search

.L_bs_found:
    addi s0, s0, -1
    j    .L_bs_outer

.L_bs_done:
    ld   s0, 0(sp)
    addi sp, sp, 8
    ret

.section .data
.align 2
.L_bs_array:
    .word 1, 3, 7, 14, 25, 42, 63, 89, 102, 127
