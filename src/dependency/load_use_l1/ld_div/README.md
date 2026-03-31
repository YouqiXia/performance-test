# LD↔DIV (L1) Forwarding Chain

测量 L1 load 与 DIV(div) 之间的往返 forwarding 延迟。

## 文档事实

- LD_lat(L1) 可从 `latency/LOAD/ld` 获取
- DIV_lat 可从 `latency/DIV/div` 获取

## 待验证

- LD→DIV + DIV→LD 的 forwarding overhead 是否为零

## Critical Section

```asm
# 构造：ld/div 交替链，t0 为链寄存器（自环指针）
# t1=1 (div identity)，div 不改变 t0 值
# .rept=20 因为 DIV 延迟很高
# insn_per_iter=2
ld   t0, 0(t0)
div  t0, t0, t1
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| LD↔DIV | ld_div | ✅ | 20 | 2 | ld→div→ld 回环 |

## 解读

- `cycles/iter` = LD→DIV fwd + DIV_lat + DIV→LD fwd + LD_lat(L1)
- forwarding_overhead = `cycles/iter` - LD_lat(L1) - DIV_lat
- 若 overhead ≈ 0：load-to-DIV forwarding 无额外延迟
- 若 overhead > 0：存在 load-use penalty 或跨 dispatch type 旁路惩罚
