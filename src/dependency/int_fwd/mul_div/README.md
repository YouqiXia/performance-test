# MUL↔DIV Forwarding Chain

测量 MUL(mul) 和 DIV(div) 之间的双向 forwarding 延迟。

## 文档事实

- MUL_lat 和 DIV_lat 可从 latency 测试获取

## 待验证

- MUL→DIV + DIV→MUL 的 forwarding overhead

## Critical Section

```asm
# 构造：mul/div 交替链，t0 为链寄存器
# t1=1 (mul identity), t2=1 (div identity)
# insn_per_iter=2
mul  t0, t0, t1
div  t0, t0, t2
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| MUL↔DIV | mul_div | ✅ | 20 | 2 | mul→div→mul 回环 |

## 解读

- forwarding_overhead = `cycles/iter` - MUL_lat - DIV_lat
