    .text
    .global test_str_match
    .balign 4
test_str_match:
    addi sp, sp, -32
    sd   s0, 0(sp)
    sd   s1, 8(sp)
    sd   s2, 16(sp)
    sd   s3, 24(sp)
    mv   s0, a0

    la   a0, .L_sm_text
    la   a1, .L_sm_pattern

    # Precompute text length
    mv   a2, a0
    li   s1, 0
.L_sm_tlen:
    lb   t1, 0(a2)
    beqz t1, .L_sm_tlen_done
    addi a2, a2, 1
    addi s1, s1, 1
    j    .L_sm_tlen
.L_sm_tlen_done:

    # Precompute pattern length
    mv   a2, a1
    li   s2, 0
.L_sm_plen:
    lb   t1, 0(a2)
    beqz t1, .L_sm_plen_done
    addi a2, a2, 1
    addi s2, s2, 1
    j    .L_sm_plen
.L_sm_plen_done:
    li   s3, 0             # match accumulator

.L_sm_outer:
    beqz s0, .L_sm_done

    sub  t6, s1, s2        # n - m
    li   t0, 0             # i = 0
    li   a3, -1            # result = -1

.L_sm_i_loop:
    bgt  t0, t6, .L_sm_i_end
    li   t1, 0             # j = 0

.L_sm_j_loop:
    bge  t1, s2, .L_sm_match
    add  t2, t0, t1
    add  t2, a0, t2
    lb   t3, 0(t2)
    add  t4, a1, t1
    lb   t5, 0(t4)
    bne  t3, t5, .L_sm_j_end
    addi t1, t1, 1
    j    .L_sm_j_loop

.L_sm_match:
    mv   a3, t0
    j    .L_sm_i_end

.L_sm_j_end:
    addi t0, t0, 1
    j    .L_sm_i_loop

.L_sm_i_end:
    add  s3, s3, a3
    addi s0, s0, -1
    j    .L_sm_outer

.L_sm_done:
    ld   s0, 0(sp)
    ld   s1, 8(sp)
    ld   s2, 16(sp)
    ld   s3, 24(sp)
    addi sp, sp, 32
    ret

.section .data
.align 4
.L_sm_text:
    .ascii "ABABDABACDABABCABABABABDABACDABABCABABABABDABACDABABCABAB"
    .byte 0
.L_sm_pattern:
    .ascii "ABABCABAB"
    .byte 0
