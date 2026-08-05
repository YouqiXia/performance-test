/*
 * ilp_width.S — K parallel independent ALU chains
 *
 * Each test_ilp_K runs K independent `addi` streams inside a .rept block.
 * Per outer iteration the total issued insns is constant (= 64), so
 * cycles/outer-iter is directly comparable across K:
 *
 *   K=1: .rept 64 × 1 addi      = 64 insns
 *   K=2: .rept 32 × 2 addi      = 64 insns
 *   K=4: .rept 16 × 4 addi      = 64 insns
 *   K=8: .rept  8 × 8 addi      = 64 insns
 *
 * Signature: void test_ilp_K(uint64_t nloop)
 *   a0 = outer loop count
 *   t3 = loop counter (caller-saved)
 *   Chains use t0,t1,t2,t4 (K≤4) and t5,t6,s0,s1 (K≤8)
 *   s0/s1 are callee-saved — we don't preserve them because main.c doesn't
 *   use them across calls and we clobber explicitly.
 */

    .text
    .align 2

/* --- K=1 ----------------------------------------------------------------- */
    .globl test_ilp_1
test_ilp_1:
    mv    t3, a0
.Lk1_loop:
    .rept 64
    addi  t0, t0, 1
    .endr
    addi  t3, t3, -1
    bnez  t3, .Lk1_loop
    ret

/* --- K=2 ----------------------------------------------------------------- */
    .globl test_ilp_2
test_ilp_2:
    mv    t3, a0
.Lk2_loop:
    .rept 32
    addi  t0, t0, 1
    addi  t1, t1, 1
    .endr
    addi  t3, t3, -1
    bnez  t3, .Lk2_loop
    ret

/* --- K=3 ----------------------------------------------------------------- */
    .globl test_ilp_3
test_ilp_3:
    mv    t3, a0
.Lk3_loop:
    /* 63 insns per outer iter (closest multiple of 3) */
    .rept 21
    addi  t0, t0, 1
    addi  t1, t1, 1
    addi  t2, t2, 1
    .endr
    addi  t3, t3, -1
    bnez  t3, .Lk3_loop
    ret

/* --- K=4 ----------------------------------------------------------------- */
    .globl test_ilp_4
test_ilp_4:
    mv    t3, a0
.Lk4_loop:
    .rept 16
    addi  t0, t0, 1
    addi  t1, t1, 1
    addi  t2, t2, 1
    addi  t4, t4, 1
    .endr
    addi  t3, t3, -1
    bnez  t3, .Lk4_loop
    ret

/* --- K=5 ----------------------------------------------------------------- */
    .globl test_ilp_5
test_ilp_5:
    mv    t3, a0
.Lk5_loop:
    /* 60 insns per outer iter */
    .rept 12
    addi  t0, t0, 1
    addi  t1, t1, 1
    addi  t2, t2, 1
    addi  t4, t4, 1
    addi  t5, t5, 1
    .endr
    addi  t3, t3, -1
    bnez  t3, .Lk5_loop
    ret

/* --- K=6 ----------------------------------------------------------------- */
    .globl test_ilp_6
test_ilp_6:
    mv    t3, a0
.Lk6_loop:
    /* 60 insns per outer iter */
    .rept 10
    addi  t0, t0, 1
    addi  t1, t1, 1
    addi  t2, t2, 1
    addi  t4, t4, 1
    addi  t5, t5, 1
    addi  t6, t6, 1
    .endr
    addi  t3, t3, -1
    bnez  t3, .Lk6_loop
    ret

/* --- K=7 ----------------------------------------------------------------- */
/* Need 7 independent regs; t0-t6 minus t3 (loop ctr) = 6 caller-saved.
 * Save s0 to reach 7. */
    .globl test_ilp_7
test_ilp_7:
    addi  sp, sp, -16
    sd    s0, 0(sp)
    mv    t3, a0
.Lk7_loop:
    /* 63 insns per outer iter */
    .rept 9
    addi  t0, t0, 1
    addi  t1, t1, 1
    addi  t2, t2, 1
    addi  t4, t4, 1
    addi  t5, t5, 1
    addi  t6, t6, 1
    addi  s0, s0, 1
    .endr
    addi  t3, t3, -1
    bnez  t3, .Lk7_loop
    ld    s0, 0(sp)
    addi  sp, sp, 16
    ret

/* --- K=8 ----------------------------------------------------------------- */
    .globl test_ilp_8
test_ilp_8:
    addi  sp, sp, -16
    sd    s0, 0(sp)
    sd    s1, 8(sp)
    mv    t3, a0
.Lk8_loop:
    .rept 8
    addi  t0, t0, 1
    addi  t1, t1, 1
    addi  t2, t2, 1
    addi  t4, t4, 1
    addi  t5, t5, 1
    addi  t6, t6, 1
    addi  s0, s0, 1
    addi  s1, s1, 1
    .endr
    addi  t3, t3, -1
    bnez  t3, .Lk8_loop
    ld    s0, 0(sp)
    ld    s1, 8(sp)
    addi  sp, sp, 16
    ret
