# LD→LD (L2) pointer chase baseline

L2 hit, 随机链表对抗 prefetcher。L2 load latency baseline, 对比 latency/LOAD/ld 看 L2 penalty。

## 文档事实

- L2 latency 一般为 6-15 cycles（取决于微架构）
- 随机链表可打败硬件 prefetcher，确保每次访问真正命中 L2

## 待验证

- L2 load-to-use latency 是多少？
- 对比 L1 版本（load_use_l1）的差值即为 L2 penalty

## Critical Section

```asm
# 构造：纯 pointer chase，t0 持续承载地址链
# 随机链表 working set = ARCH_L2_WORKING_SET (1MB)，确保 L2 hit
# .rept 100 提供足够迭代，insn_per_iter=1
ld   t0, 0(t0)       # ✅ t0→t0 链式依赖
```

## 测试列表

| Variant | 链 | .rept | insn_per_iter | 说明 |
|---------|-----|-------|---------------|------|
| ld_ld   | ✅  | 100   | 1             | 纯 pointer chase baseline |

## 解读

- cycles/iter 即为 L2 load-to-use latency
- 对比 load_use_l1 的 ld→ld 结果，差值为 L2 vs L1 penalty
- 此值为后续 ld_alu / ld_mul / ld_div 的 baseline
