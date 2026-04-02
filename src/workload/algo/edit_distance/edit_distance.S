    .text
    .global test_edit_distance
    .balign 4
test_edit_distance:
    addi sp, sp, -64
    sd   ra, 0(sp)
    sd   s0, 8(sp)
    sd   s1, 16(sp)
    sd   s2, 24(sp)
    sd   s3, 32(sp)
    sd   s4, 40(sp)
    sd   s5, 48(sp)

    mv   s5, a0            # s5 = nloop
    la   s0, .L_ed_str1    # s0 = string 1
    la   s1, .L_ed_str2    # s1 = string 2
    li   s2, 5             # m = len("kitten")
    li   s3, 6             # n = len("sitting") - using small strings for reasonable runtime

.L_ed_repeat:
    beqz s5, .L_ed_done

    # Allocate dp array: (m+1)*(n+1)*8 on stack
    addi t0, s2, 1
    addi t1, s3, 1
    mul  t2, t0, t1
    slli t2, t2, 3
    sub  sp, sp, t2

    # Init dp[0][j] = j
    li   t0, 0             # i = 0
    li   t1, 0             # j = 0
.L_ed_init_row:
    bgt  t1, s3, .L_ed_init_row_done
    mul  t2, t0, t1
    slli t2, t2, 3
    add  t3, sp, t2
    sd   t1, 0(t3)
    addi t1, t1, 1
    j    .L_ed_init_row
.L_ed_init_row_done:

    # Init dp[i][0] = i
    li   t0, 1
.L_ed_init_col:
    bgt  t0, s2, .L_ed_init_col_done
    li   t1, 0
    mul  t2, t0, t1
    slli t2, t2, 3
    add  t3, sp, t2
    sd   t0, 0(t3)
    addi t0, t0, 1
    j    .L_ed_init_col
.L_ed_init_col_done:

    # Main DP loop
    li   s4, 1             # i = 1
.L_ed_outer:
    bgt  s4, s2, .L_ed_outer_done
    li   t0, 1             # j = 1
.L_ed_inner:
    bgt  t0, s3, .L_ed_inner_done

    # Compare s1[i-1] and s2[j-1]
    addi t1, s4, -1
    add  t1, s0, t1
    lbu  t1, 0(t1)
    addi t2, t0, -1
    add  t2, s1, t2
    lbu  t2, 0(t2)

    beq  t1, t2, .L_ed_same

    # Different: dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
    # dp[i-1][j]
    addi t1, s4, -1
    mul  t1, t1, t0
    slli t1, t1, 3
    add  t1, sp, t1
    ld   t2, 0(t1)

    # dp[i][j-1]
    mul  t1, s4, t0
    addi t1, t1, -1
    slli t1, t1, 3
    add  t1, sp, t1
    ld   t3, 0(t1)

    # dp[i-1][j-1]
    addi t1, s4, -1
    mul  t1, t1, t0
    addi t1, t1, -1
    slli t1, t1, 3
    add  t1, sp, t1
    ld   t4, 0(t1)

    # min3
    blt  t2, t3, .L_ed_min1
    mv   t5, t3
    j    .L_ed_min2
.L_ed_min1:
    mv   t5, t2
.L_ed_min2:
    blt  t5, t4, .L_ed_min3
    mv   t6, t4
    j    .L_ed_min_done
.L_ed_min3:
    mv   t6, t5
.L_ed_min_done:
    addi t6, t6, 1

    mul  t1, s4, t0
    slli t1, t1, 3
    add  t1, sp, t1
    sd   t6, 0(t1)
    j    .L_ed_next

.L_ed_same:
    # dp[i][j] = dp[i-1][j-1]
    addi t1, s4, -1
    mul  t1, t1, t0
    addi t1, t1, -1
    slli t1, t1, 3
    add  t1, sp, t1
    ld   t2, 0(t1)
    mul  t1, s4, t0
    slli t1, t1, 3
    add  t1, sp, t1
    sd   t2, 0(t1)

.L_ed_next:
    addi t0, t0, 1
    j    .L_ed_inner
.L_ed_inner_done:
    addi s4, s4, 1
    j    .L_ed_outer
.L_ed_outer_done:

    # Result in dp[m][n]
    mul  t0, s2, s3
    slli t0, t0, 3
    add  t0, sp, t0
    ld   a0, 0(t0)

    # Free dp array
    addi t1, s2, 1
    addi t2, s3, 1
    mul  t0, t1, t2
    slli t0, t0, 3
    add  sp, sp, t0

    addi s5, s5, -1
    j    .L_ed_repeat

.L_ed_done:
    ld   ra, 0(sp)
    ld   s0, 8(sp)
    ld   s1, 16(sp)
    ld   s2, 24(sp)
    ld   s3, 32(sp)
    ld   s4, 40(sp)
    ld   s5, 48(sp)
    addi sp, sp, 64
    ret

.section .data
.L_ed_str1:
    .ascii "kitte"
    .byte 0
.L_ed_str2:
    .ascii "sittin"
    .byte 0
