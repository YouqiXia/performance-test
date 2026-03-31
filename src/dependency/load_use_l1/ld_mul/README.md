# LD↔MUL (L1) Forwarding Chain

测量 L1 load 与 MUL(mul) 之间的往返 forwarding 延迟。

## 文档事实

- LD_lat(L1) 可从 `latency/LOAD/ld` 获取
- MUL_lat 可从 `latency/MUL/mul` 获取

## 待验证

- LD→MUL + MUL→LD 的 forwarding overhead 是否为零

## Critical Section

```asm
# 构造：ld/mul 交替链，t0 为链寄存器（自环指针）
# t1=1 (mul identity)，mul 不改变 t0 值
# insn_per_iter=2
ld   t0, 0(t0)
mul  t0, t0, t1
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| LD↔MUL | ld_mul | ✅ | 100 | 2 | ld→mul→ld 回环 |

## 解读

- `cycles/iter` = LD→MUL fwd + MUL_lat + MUL→LD fwd + LD_lat(L1)
- forwarding_overhead = `cycles/iter` - LD_lat(L1) - MUL_lat
- 若 overhead ≈ 0：load-to-MUL forwarding 无额外延迟
- 若 overhead > 0：存在 load-use penalty 或跨 dispatch type 旁路惩罚
