    .text
    .global test_quick_select
    .balign 4
test_quick_select:
    addi sp, sp, -16
    sd   s0, 0(sp)
    sd   ra, 8(sp)
    mv   s0, a0

.L_qs_outer:
    beqz s0, .L_qs_done
    la   a0, .L_qs_array
    li   a1, 0             # left
    li   a2, 5             # right = n-1
    li   a3, 2             # k
    jal  ra, .L_qs_select

    addi s0, s0, -1
    j    .L_qs_outer

.L_qs_done:
    ld   s0, 0(sp)
    ld   ra, 8(sp)
    addi sp, sp, 16
    ret

# partition: a0=arr, a1=left, a2=right -> a0=pivot_index
.L_qs_partition:
    slli t0, a2, 2
    add  t0, a0, t0
    lw   t1, 0(t0)         # pivot = arr[right]
    addi t2, a1, -1         # i = left-1
    mv   t3, a1             # j = left

.L_qs_part_loop:
    bge  t3, a2, .L_qs_part_end
    slli t4, t3, 2
    add  t4, a0, t4
    lw   t5, 0(t4)
    bgt  t5, t1, .L_qs_part_skip
    addi t2, t2, 1
    slli t6, t2, 2
    add  t6, a0, t6
    lw   a4, 0(t6)
    lw   a5, 0(t4)
    sw   a5, 0(t6)
    sw   a4, 0(t4)
.L_qs_part_skip:
    addi t3, t3, 1
    j    .L_qs_part_loop

.L_qs_part_end:
    addi t2, t2, 1
    slli t4, t2, 2
    add  t4, a0, t4
    slli t5, a2, 2
    add  t5, a0, t5
    lw   a4, 0(t4)
    lw   a5, 0(t5)
    sw   a5, 0(t4)
    sw   a4, 0(t5)
    mv   a0, t2
    ret

# quick_select: a0=arr, a1=left, a2=right, a3=k -> a0=value
.L_qs_select:
    beq  a1, a2, .L_qs_ret_left
    addi sp, sp, -32
    sd   ra, 0(sp)
    sd   a0, 8(sp)
    sd   a3, 16(sp)
    jal  ra, .L_qs_partition
    mv   t0, a0             # pivot_index
    ld   a3, 16(sp)
    ld   a0, 8(sp)
    ld   ra, 0(sp)
    addi sp, sp, 32
    beq  a3, t0, .L_qs_found
    blt  a3, t0, .L_qs_left
    addi a1, t0, 1
    j    .L_qs_select
.L_qs_left:
    addi a2, t0, -1
    j    .L_qs_select
.L_qs_found:
    slli t1, a3, 2
    add  t1, a0, t1
    lw   a0, 0(t1)
    ret
.L_qs_ret_left:
    slli t1, a1, 2
    add  t1, a0, t1
    lw   a0, 0(t1)
    ret

.section .data
.align 4
.L_qs_array:
    .word 7, 10, 4, 3, 20, 15
