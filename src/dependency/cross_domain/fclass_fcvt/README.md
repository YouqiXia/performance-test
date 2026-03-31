# FCLASS<->FCVT Cross-Domain Chain

测量 fclass.d (FP->INT classify) 和 fcvt.d.w (INT->FP convert) 之间的跨域往返延迟。

## 文档事实

- fclass.d 读取浮点寄存器，输出 10-bit 分类掩码到整数寄存器
- fcvt.d.w 将整数寄存器转换为双精度浮点
- fclass 输出值较小（0-9 位掩码），fcvt.d.w 将其转换回 FP 域后值仍为正常正数

## 待验证

- fclass (FP->INT) + fcvt.d.w (INT->FP) 的往返延迟
- fclass 的 FP->INT 路径延迟是否与 fcvt.w.d 不同（classify vs. convert）

## Critical Section

```asm
# 构造：fclass.d/fcvt.d.w 交替链，t0 为 INT 链寄存器，ft0 为 FP 链寄存器
# ft0 由 main.c 初始化为 1.0，fclass 输出 bit 7 (positive normal) = 128
# fcvt.d.w 将 128 转回 FP 域，产生 128.0（仍为正常正数），链可持续
# insn_per_iter=2
fclass.d  t0, ft0
fcvt.d.w  ft0, t0
```

## 测试列表

| Test | 路径 | 链 | .rept | insn_per_iter | 说明 |
|------|------|-----|-------|---------------|------|
| FCLASS<->FCVT | fclass_fcvt | ✅ | 100 | 2 | fclass.d->fcvt.d.w 回环 |

## 解读

- cycles/iter = fclass (FP->INT classify) latency + fcvt.d.w (INT->FP convert) latency
- 与 fcvt_roundtrip 对比：若 fclass 延迟 < fcvt.w.d 延迟，则本测试 cycles/iter 更低
- fclass 走的是 FP classify 单元而非 FP convert 单元，可能有不同的 forwarding 路径
