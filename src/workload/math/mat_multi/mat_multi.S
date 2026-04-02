    .text
    .global test_mat_multi
    .balign 4
test_mat_multi:
    addi sp, sp, -48
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    sd   s2, 16(sp)
    sd   s3, 24(sp)
    sd   s4, 32(sp)
    sd   s5, 40(sp)
    mv   s0, a0

    la   a0, .L_mm_A
    la   a1, .L_mm_B
    la   a2, .L_mm_C
    li   t0, 8

.L_mm_outer:
    beqz s0, .L_mm_done

    # Clear C
    mv   t1, a2
    li   t2, 0
    li   t3, 64
.L_mm_clear:
    sw   zero, 0(t1)
    addi t1, t1, 4
    addi t2, t2, 1
    blt  t2, t3, .L_mm_clear

    li   t1, 0             # i
.L_mm_i:
    li   t2, 0             # j
.L_mm_j:
    mul  t3, t1, t0
    add  t3, t3, t2
    slli t3, t3, 2
    add  s1, a2, t3        # &C[i][j]
    li   t4, 0             # k
    li   s2, 0             # sum
.L_mm_k:
    mul  t5, t1, t0
    add  t5, t5, t4
    slli t5, t5, 2
    add  t5, a0, t5
    lw   s3, 0(t5)         # A[i][k]
    mul  t5, t4, t0
    add  t5, t5, t2
    slli t5, t5, 2
    add  t5, a1, t5
    lw   s4, 0(t5)         # B[k][j]
    mul  s3, s3, s4
    add  s2, s2, s3
    addi t4, t4, 1
    blt  t4, t0, .L_mm_k
    sw   s2, 0(s1)
    addi t2, t2, 1
    blt  t2, t0, .L_mm_j
    addi t1, t1, 1
    blt  t1, t0, .L_mm_i

    addi s0, s0, -1
    j    .L_mm_outer

.L_mm_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    ld   s2, 16(sp)
    ld   s3, 24(sp)
    ld   s4, 32(sp)
    ld   s5, 40(sp)
    addi sp, sp, 48
    ret

.section .data
.align 4
.L_mm_A:
    .rept 64
    .word 1
    .endr
.L_mm_B:
    .rept 64
    .word 2
    .endr
.L_mm_C:
    .space 256
