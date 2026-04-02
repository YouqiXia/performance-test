#ifndef STORE_COMMON_H
#define STORE_COMMON_H

/*
 * Memory ordering 测试公共配置
 * NFAST: 每组慢操作后跟的快 load 数量，改这一处即可
 */
#ifndef NFAST
#define NFAST 40
#endif

#ifdef __ASSEMBLER__

/* 发射 NFAST 个 ld，从 base 的不同偏移读（每个 +8） */
.macro emit_fast_ld_diff base
    .set _off, 0
    .rept NFAST
    ld   t4, _off(\base)
    .set _off, _off + 8
    .endr
.endm

/* 发射 NFAST 个 ld，全部读 base+0（同地址） */
.macro emit_fast_ld_same base
    .rept NFAST
    ld   t4, 0(\base)
    .endr
.endm

#endif /* __ASSEMBLER__ */
#endif /* STORE_COMMON_H */
