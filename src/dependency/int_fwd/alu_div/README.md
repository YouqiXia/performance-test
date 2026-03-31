# ALU↔DIV Forwarding Chain

测量 ALU(add) 和 DIV(div) 之间的双向 forwarding 延迟。

## 文档事实

- ALU_lat 和 DIV_lat 可从 latency 测试获取
- DIV 延迟较高（~17 cycles），.rept=20 避免单轮过长

## 待验证

- ALU→DIV + DIV→ALU 的 forwarding overhead

## Critical Section

```asm
# 构造：add/div 交替链，t0 为链寄存器
# t1=0 (add identity), t2=1 (div identity)
# insn_per_iter=2
add  t0, t0, t1
div  t0, t0, t2
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| ALU↔DIV | alu_div | ✅ | 20 | 2 | add→div→add 回环 |

## 解读

- forwarding_overhead = `cycles/iter` - ALU_lat - DIV_lat
