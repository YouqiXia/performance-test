# LD↔ALU (L2) forwarding chain

L2 hit, 随机链表对抗 prefetcher。forwarding_overhead = cycles/iter - LD_lat(L2) - consumer_lat. 对比 L1 版本看 L2 是否影响 forwarding。

## 文档事实

- ALU (add) latency = 1 cycle
- L2 load latency 由 ld_ld baseline 测得

## 待验证

- LD→ALU forwarding 在 L2 hit 场景下是否有额外开销？
- 对比 load_use_l1/ld_alu，L2 penalty 是否完全由 load latency 解释？

## Critical Section

```asm
# 构造：ld→add 往返链，t0 持续承载地址
# add zero 为恒等操作，不改变指针值
# 随机链表 working set = ARCH_L2_WORKING_SET (1MB)
# .rept 100, insn_per_iter=2
ld   t0, 0(t0)       # ✅ ld 写 t0
add  t0, t0, zero     # ✅ add 读/写 t0，zero 保持地址不变
```

## 测试列表

| Variant | 链 | .rept | insn_per_iter | 说明 |
|---------|-----|-------|---------------|------|
| ld_alu  | ✅  | 100   | 2             | ld→add 往返链 (L2) |

## 解读

- cycles/iter - ld_ld(L2) baseline = ALU latency + forwarding overhead
- 若该差值与 L1 版本相同，说明 L2 不影响 forwarding path
- 若差值更大，说明 L2 miss path 引入额外 forwarding penalty
