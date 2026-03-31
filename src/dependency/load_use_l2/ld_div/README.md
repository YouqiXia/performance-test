# LD↔DIV (L2) forwarding chain

L2 hit, 随机链表对抗 prefetcher。forwarding_overhead = cycles/iter - LD_lat(L2) - consumer_lat. 对比 L1 版本看 L2 是否影响 forwarding。

## 文档事实

- DIV latency 一般为 20-40 cycles（数据依赖）
- L2 load latency 由 ld_ld baseline 测得

## 待验证

- LD→DIV forwarding 在 L2 hit 场景下是否有额外开销？
- DIV latency 足够长，可能完全隐藏 L2 penalty（与 L1 版本结果相同）
- 对比 load_use_l1/ld_div，验证长 latency consumer 是否能隐藏 L2 访问延迟

## Critical Section

```asm
# 构造：ld→div 往返链，t0 持续承载地址
# t1 = 1，div 恒等操作不改变指针值
# 随机链表 working set = ARCH_L2_WORKING_SET (1MB)
# DIV 很慢所以 .rept 20, insn_per_iter=2
ld   t0, 0(t0)       # ✅ ld 写 t0
div  t0, t0, t1       # ✅ div 读/写 t0，t1=1 保持地址不变
```

## 测试列表

| Variant | 链 | .rept | insn_per_iter | 说明 |
|---------|-----|-------|---------------|------|
| ld_div  | ✅  | 20    | 2             | ld→div 往返链 (L2) |

## 解读

- cycles/iter - ld_ld(L2) baseline = DIV latency + forwarding overhead
- 若该差值与 L1 版本相同，说明 DIV latency 完全隐藏了 L2 penalty
- 若 L2 版本 cycles/iter 与 L1 版本相同，说明 DIV 执行时间 > L2 load latency，L2 延迟被完全重叠
