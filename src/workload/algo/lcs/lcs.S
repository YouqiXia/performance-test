    .text
    .global test_lcs
    .balign 4
test_lcs:
    addi sp, sp, -48
    sd   ra, 0(sp)
    sd   s0, 8(sp)
    sd   s1, 16(sp)
    sd   s2, 24(sp)
    sd   s3, 32(sp)
    sd   s4, 40(sp)

    mv   s4, a0            # nloop
    la   s0, .L_lcs_str1
    la   s1, .L_lcs_str2
    li   a2, 6             # m
    li   a3, 5             # n

    # Allocate DP table
    addi t0, a2, 1
    addi t1, a3, 1
    mul  t2, t0, t1
    slli t2, t2, 3
    addi t3, t2, 15
    andi t3, t3, -16
    sub  sp, sp, t3
    mv   s2, sp            # DP base

    addi s3, a3, 1
    slli s3, s3, 3         # row stride = (n+1)*8

.L_lcs_repeat:
    beqz s4, .L_lcs_done

    # Init DP to 0
    li   t0, 0
.L_lcs_init_i:
    bgt  t0, a2, .L_lcs_init_done
    li   t1, 0
.L_lcs_init_j:
    bgt  t1, a3, .L_lcs_init_j_done
    mul  t4, t0, s3
    slli t5, t1, 3
    add  t4, t4, t5
    add  t4, s2, t4
    sd   zero, 0(t4)
    addi t1, t1, 1
    j    .L_lcs_init_j
.L_lcs_init_j_done:
    addi t0, t0, 1
    j    .L_lcs_init_i
.L_lcs_init_done:

    # Fill DP table
    li   t0, 1
.L_lcs_outer:
    bgt  t0, a2, .L_lcs_outer_done
    li   t1, 1
.L_lcs_inner:
    bgt  t1, a3, .L_lcs_inner_done

    addi t4, t0, -1
    add  t4, s0, t4
    lb   t6, 0(t4)         # s1[i-1]
    addi t4, t1, -1
    add  t4, s1, t4
    lb   t5, 0(t4)         # s2[j-1]

    bne  t6, t5, .L_lcs_neq

    # Equal: dp[i][j] = dp[i-1][j-1] + 1
    addi t4, t0, -1
    mul  t4, t4, s3
    addi t5, t1, -1
    slli t5, t5, 3
    add  t4, t4, t5
    add  t4, s2, t4
    ld   a4, 0(t4)
    addi a4, a4, 1
    mul  t4, t0, s3
    slli t5, t1, 3
    add  t4, t4, t5
    add  t4, s2, t4
    sd   a4, 0(t4)
    j    .L_lcs_next_j

.L_lcs_neq:
    # dp[i-1][j]
    addi t4, t0, -1
    mul  t4, t4, s3
    slli t5, t1, 3
    add  t4, t4, t5
    add  t4, s2, t4
    ld   a4, 0(t4)
    # dp[i][j-1]
    mul  t4, t0, s3
    addi t5, t1, -1
    slli t5, t5, 3
    add  t4, t4, t5
    add  t4, s2, t4
    ld   a5, 0(t4)
    ble  a4, a5, .L_lcs_use_ij1
    mv   a5, a4
.L_lcs_use_ij1:
    mul  t4, t0, s3
    slli t5, t1, 3
    add  t4, t4, t5
    add  t4, s2, t4
    sd   a5, 0(t4)

.L_lcs_next_j:
    addi t1, t1, 1
    j    .L_lcs_inner
.L_lcs_inner_done:
    addi t0, t0, 1
    j    .L_lcs_outer
.L_lcs_outer_done:

    addi s4, s4, -1
    j    .L_lcs_repeat

.L_lcs_done:
    addi t0, a2, 1
    addi t1, a3, 1
    mul  t2, t0, t1
    slli t2, t2, 3
    addi t3, t2, 15
    andi t3, t3, -16
    add  sp, sp, t3

    ld   ra, 0(sp)
    ld   s0, 8(sp)
    ld   s1, 16(sp)
    ld   s2, 24(sp)
    ld   s3, 32(sp)
    ld   s4, 40(sp)
    addi sp, sp, 48
    ret

.section .data
.L_lcs_str1:
    .ascii "ABCBDA"
    .byte 0
.L_lcs_str2:
    .ascii "ABDCA"
    .byte 0
