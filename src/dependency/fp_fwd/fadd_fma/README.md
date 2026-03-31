# FADD↔FMA Forwarding Chain

测量 FADD(fadd.d) 和 FMA(fmadd.d) 之间的双向 forwarding 延迟。

## 文档事实

- FADD_lat 和 FMA_lat 可从 `latency/FADD/fadd_d` 和 `latency/FMA/fmadd_d` 获取

## 待验证

- FADD→FMA + FMA→FADD 的 forwarding overhead 是否为零（即无额外旁路延迟）

## Critical Section

```asm
# 构造：fadd.d/fmadd.d 交替链，ft0 为链寄存器
# ft1=0.0 (fadd identity), ft2=1.0 (fmadd mul identity), ft3=0.0 (fmadd add identity)
# fmadd.d: ft0 = ft0*ft2+ft3 = ft0*1.0+0.0 = ft0
# insn_per_iter=2
fadd.d   ft0, ft0, ft1
fmadd.d  ft0, ft0, ft2, ft3
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FADD↔FMA | fadd_fma | ✅ | 100 | 2 | fadd.d→fmadd.d→fadd.d 回环 |

## 解读

- `cycles/iter` = FADD→FMA fwd + FMA_lat + FMA→FADD fwd + FADD_lat
- forwarding_overhead = `cycles/iter` - FADD_lat - FMA_lat
- 若 overhead ≈ 0：FADD 和 FMA 共享旁路网络
- 若 overhead > 0：存在跨 FADD/FMA dispatch type 的旁路惩罚
