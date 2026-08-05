# slre 性能分析

## 1. 源码分析

### 1.1 基本信息

| 项目 | 值 |
|------|-----|
| 源文件 | `thirdparty/embench-iot/src/slre/libslre.c`, `slre.h` |
| 算法描述 | 轻量级正则表达式引擎（Super Light Regular Expression），支持 `()`, `[]`, `*`, `+`, `?`, `\S`, `\s`, `\d` 等 |
| LOCAL_SCALE_FACTOR | 116 |
| 数据类型 | `char`（字符匹配）、`int`（索引和长度）、`struct regex_info`（栈上大结构体 ~3KB） |
| 输入文本 | 45 字节固定字符串 `"abbbababaabccababcacbcbcbabbabcbabcabcbbcbbac"` |
| 正则表达式 | 4 个：`(ab)+`, `(b.+)+`, `a[ab]*`, `([ab^c][ab^c])+` |

### 1.2 调用链

```
benchmark()
  benchmark_body(116, 1)            // LSF=116, GSF=1
    for lsf_cnt in 0..115:
      for gsf_cnt in 0..0:
        strlen(text)                // len=45
        for i in 0..3:
          slre_match(regexes[i], text, 45, &captures, 1)
            foo()                   // 单次遍历 regex，记录 brackets/branches
              setup_branch_points() // 排序 branches
              baz()                 // 从每个位置尝试匹配
                doh()               // 处理 branch alternation
                  bar()             // 核心递归匹配引擎
                    match_op()      // 单字符匹配
                    match_set()     // 字符集 [] 匹配
                    bar() [递归]    // 量词 */+ 处理
                    doh() [递归]    // 子括号匹配
```

### 1.3 核心计算函数

核心匹配函数 `bar()` 是一个递归下降的正则匹配器，对 regex 和 subject 字符串做双指针扫描：

```c
static int
bar (const char *re, int re_len, const char *s, int s_len,
     struct regex_info *info, int bi)
{
  int i, j, n, step;
  for (i = j = 0; i < re_len && j <= s_len; i += step)
  {
    step = re[i] == '(' ? info->brackets[bi + 1].len + 2 :
      get_op_len (re + i, re_len - i);
    // ... 量词处理（递归 bar）
    // ... 字符集 [] 匹配
    // ... 括号 () 匹配（递归 doh -> bar）
    // ... 单字符匹配（调用 match_op）
  }
  return j;
}
```

`match_op()` 执行单字符比较：

```c
static int
match_op (const unsigned char *re, const unsigned char *s,
          struct regex_info *info)
{
  switch (*re) {
    case '\\': /* 元字符 \S, \s, \d, \x */ break;
    case '.':  result++; break;
    default:   if (*re != *s) return SLRE_NO_MATCH; result++; break;
  }
  return result;
}
```

### 1.4 循环结构

| 循环层 | 变量 | Trip Count | 说明 |
|--------|------|------------|------|
| L0 | lsf_cnt | 116 | LSF 缩放循环 |
| L1 | gsf_cnt | 1 | GSF 缩放循环（单次） |
| L2 | i | 4 | 4 个正则表达式 |
| L3 | baz::i | 0..45 | 从 subject 每个位置尝试匹配 |
| L4 | bar::i,j | 可变 | regex/subject 双指针扫描 |
| L5 | 量词 do-while | 可变 | `*`/`+` 贪婪匹配循环 |

总外层迭代：116 x 1 x 4 = 464 次 `slre_match` 调用。

### 1.5 访存模式

- **栈上大结构体**：`struct regex_info` 包含 `brackets[100]`（24B each）和 `branches[100]`（16B each），总约 4KB，每次 `slre_match` 分配在栈上
- **字符串随机访问**：regex 和 subject 字符串的字符级随机访问（`lbu` 指令）
- **指针追逐**：`bar()` 递归调用，每层创建新栈帧，造成栈深度变化
- **全局数据小**：text（45B）和 regexes 数组（4 个指针）驻留在 .data 段

### 1.6 计算特征

- **控制流密集**：大量 switch-case、条件分支（正则状态机转换）
- **递归调用**：`bar` <-> `doh` 互相递归，调用深度取决于 regex 复杂度
- **字符比较**：核心操作是 `lbu` + 比较，整数 ALU 操作为主
- **无浮点**：纯整数/字符操作
- **分支密度高**：每个字符匹配都涉及多路判断（元字符类型、量词类型等）

## 2. 汇编热点分析

### 2.1 Spike 执行概况

| 指标 | 值 |
|------|-----|
| 总指令数 (instret) | 2,750,642 |
| 总周期数 (cycles) | 2,750,638 |
| IPC (spike) | 1.0000 |
| trace 总行数 | 3,561,106 |
| 用户态指令数 | ~2,911,000 |

### 2.2 核心函数反汇编

**bar() 内层循环入口** (0x105ea - 0x10680，占比 72.1%)：

```asm
# bar 主循环：从 regex 位置 s10 开始扫描
105ea:  add   a0, s9, s10           # a0 = re + i (当前 regex 位置)
105ee:  lbu   a1, 0(a0)             # a1 = re[i] (加载当前 regex 字符)
105f2:  li    a5, 40                # '(' = 40
105f6:  bne   a1, a5, 10684         # 不是 '(' 则跳到字符/集合匹配

# set_len 内层循环（处理 [...]）
1072a:  addiw a4, s4, 1             # a4 = len + 1
1072e:  add   a3, a0, a4            # a3 = re + i + len + 1
10732:  lbu   a5, 0(a3)             # a5 = re[len] (加载字符集中的字符)
10736:  beq   a5, t3, 10744         # 找到 ']' 则结束
1073a:  beq   a5, t4, 10a3e         # 找到 '\\' 则特殊处理
1073e:  mv    s4, a4                # len = len + 1
10740:  blt   s4, a2, 1072a         # len < re_len 则继续
```

**match_op() 入口** (0x1042a - 0x104da，占比 12.8%)：

```asm
1042a:  addi  sp, sp, -48           # 栈帧
1042e:  lbu   a5, 0(a0)             # a5 = *re (regex 字符)
10432:  li    a4, 92                # '\\' = 92
10436:  beq   a5, a4, 10498         # 转义字符处理
1043a:  bltu  a4, a5, 10458         # > '\\' 则可能是 '|'
1043e:  li    a4, 36                # '$' = 36
10442:  li    a0, -1                # 默认返回 NO_MATCH
10444:  beq   a5, a4, 10452         # '$' 匹配
10448:  li    a4, 46                # '.' = 46
1044c:  li    a0, 1                 # '.' 匹配任意字符
1044e:  bne   a5, a4, 10462         # 不是 '.' 则走默认比较
# ... 默认路径：直接字符比较
10462:  addi  a2, a2, 2047          # 访问 info->flags
10466:  lw    a4, 1981(a2)          # 加载 flags
1046a:  lbu   a3, 0(a1)             # a3 = *s (subject 字符)
1046e:  andi  a4, a4, 1             # 检查 IGNORE_CASE
10470:  beqz  a4, 104da             # 非忽略大小写
# ...
104da:  bne   a5, a3, 104d6         # *re != *s -> NO_MATCH
104de:  li    a0, 1                 # 返回 1（匹配成功）
```

**match_set 字符集内层循环** (0x107ca - 0x10818)：

```asm
# 遍历字符集 [...] 中的字符
107ca:  beq   s4, s8, 10818         # s4 == ']' 则结束
107cc:  li    a5, 1
107d0:  add   s5, s3, s2            # s5 = re + offset
107d4:  beq   s4, s6, 1097e         # 检查是否是 '-'（范围）
107d8:  lbu   a5, 1(s5)             # 预取下一个字符
107dc:  beq   a5, s6, 10990         # 是 'x-y' 范围
107e0:  mv    a2, s7                # info
107e2:  mv    a1, s1                # subject char
107e4:  mv    a0, s5                # regex char
107e6:  jal   match_op              # 调用 match_op
```

### 2.3 热点 PC 分布

| 函数 | 指令数 | 占比 | 说明 |
|------|--------|------|------|
| bar() | 2,098,044 | 72.1% | 递归匹配引擎主体 |
| match_op() | 372,645 | 12.8% | 单字符匹配 |
| doh() | 159,471 | 5.5% | 分支点处理 |
| slre_match/foo/baz() | 107,991 | 3.7% | 入口+预处理+位置扫描 |
| benchmark_body() | 6,388 | 0.2% | 外层循环开销 |
| 其他（libc等） | ~166,461 | 5.7% | strlen, ctype 等 |

bar() 内部最热 PC 段（set_len 扫描循环 0x1072a-0x10740）：每个 PC 执行 31,122 次。

### 2.4 内层循环微架构分析

**bar() 主循环特征**：
- 指令混合：lbu（字符加载）、beq/bne（分支判断）、addiw（索引递增）、add（地址计算）
- 循环携带依赖：i (s10) 和 j (s5) 通过 addw 更新，依赖链长度 1 cycle
- 分支密度极高：平均每 3-4 条指令就有一个条件分支
- 分支可预测性差：regex 匹配结果依赖输入数据，switch-case 跳转目标多变

**match_op() 特征**：
- 5 路 switch 分支（'\\'、'|'、'$'、'.'、default）
- 大部分调用走 default 路径（直接字符比较）
- 调用开销：jal/ret 对，每次 match_op 约 6-10 条指令
- lbu 加载 1 byte 字符后立即比较，load-to-use 延迟是关键路径

**预计 IPC（乱序核）**：
- 分支密集 + 数据依赖 load (lbu) -> 分支结果受限于 load 延迟
- 递归调用造成频繁的栈操作（sd/ld callee-saved regs）
- 预计 IPC：1.2-1.8（受分支预测准确率限制）

## 3. 总结

| 项目 | 值 |
|------|-----|
| 算法 | 递归下降正则表达式匹配 |
| 数据量 | 45 字节文本 x 4 个 regex x 116 次 |
| 计算类型 | 整数/字符比较，控制流密集 |
| 内层循环指令数 | bar 主循环体 ~20-30 条/iteration（可变） |
| 内层循环占比 | bar() 72.1% + match_op() 12.8% = 84.9% |
| 瓶颈预测 | 分支预测（高密度条件跳转+递归调用），load-to-branch 延迟链 |

**微架构敏感点**：
1. **分支预测器压力**：bar() 中每 3-4 条指令一个分支，且多为数据相关分支（字符比较结果决定），BTB/TAGE 预测器准确率对性能影响极大
2. **递归调用栈**：bar <-> doh 互递归，频繁的 JAL/RET 对，RAS (Return Address Stack) 深度是否足够
3. **字符加载延迟**：lbu 后紧跟比较分支，L1D 命中延迟直接影响分支 resolve 时间
4. **指令缓存**：bar() 函数体 ~1.4KB，match_op ~400B，doh ~180B，总热点代码约 2KB，应能完全驻留 L1I
