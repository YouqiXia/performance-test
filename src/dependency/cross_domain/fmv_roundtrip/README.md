# FMV INT<->FP Roundtrip

测量 fmv.d.x (INT->FP) 和 fmv.x.d (FP->INT) 之间的跨域 bitwise move 往返延迟。

## 文档事实

- fmv.d.x 将整数寄存器的位模式直接搬到浮点寄存器（无转换）
- fmv.x.d 将浮点寄存器的位模式直接搬到整数寄存器（无转换）
- 与 fcvt 不同，fmv 不进行格式转换，仅跨域搬运原始位

## 待验证

- INT->FP bitwise move + FP->INT bitwise move 的往返延迟
- 纯 bitwise move 的跨域 forwarding 延迟是否低于 fcvt 转换

## Critical Section

```asm
# 构造：fmv.d.x/fmv.x.d 交替链，t0 为 INT 链寄存器，ft0 为 FP 中间寄存器
# t0 初始化为 42，值不影响 bitwise move 延迟
# insn_per_iter=2
fmv.d.x  ft0, t0
fmv.x.d  t0, ft0
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FMV INT<->FP | fmv_roundtrip | ✅ | 100 | 2 | fmv.d.x->fmv.x.d 回环 |

## 解读

- cycles/iter = INT->FP bitwise move latency + FP->INT bitwise move latency
- 与 fcvt_roundtrip 对比，差值反映格式转换 vs. 纯搬运的额外开销
- 若两者延迟相同，说明跨域延迟由物理搬运主导而非转换逻辑
