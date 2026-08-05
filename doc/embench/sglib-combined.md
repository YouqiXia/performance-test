# sglib-combined 性能分析

## 1. 源码分析

### 1.1 基本信息
- **源文件**: `thirdparty/embench-iot/src/sglib-combined/combined.c`, `sglib.h`
- **算法描述**: SGLIB 泛型数据结构库综合测试，包含 5 种数据结构操作
- **LOCAL_SCALE_FACTOR**: 31
- **数据类型**: `int`（32-bit），`struct dllist`/`ilist`/`rbtree`（链表/哈希/红黑树节点）

### 1.2 调用链
```
benchmark() → benchmark_body(lsf=31, gsf=1)
  └→ 循环 31×1 = 31 次 (+1 warmup = 32 次)
      ├→ [1] Array Quicksort
      │   ├→ memcpy(array2 ← array, 400B)              # 拷贝 100 个 int
      │   └→ SGLIB_ARRAY_SINGLE_QUICK_SORT(array2, 100) # 快速排序
      │
      ├→ [2] Doubly Linked List
      │   ├→ init_heap_beebs()
      │   ├→ for i=0..99: malloc_beebs + sglib_dllist_add()  # 插入 100 个节点
      │   ├→ sglib_dllist_sort()                              # 归并排序
      │   └→ for l=first..NULL: cnt++                         # 遍历计数
      │
      ├→ [3] Hash Table
      │   ├→ sglib_hashed_ilist_init(htab)              # 初始化 20 槽哈希表
      │   ├→ for i=0..99: find + malloc + add           # 插入 100 个元素
      │   └→ iterator 遍历: cnt++                        # 遍历计数
      │
      ├→ [4] Queue + Heap (Priority Queue)
      │   ├→ Queue: add 100 → delete all, cnt += values # FIFO
      │   ├→ Heap add: SGLIB_HEAP_ADD × 100             # 最大堆插入
      │   └→ Heap delete: SGLIB_HEAP_DELETE × 100       # 堆顶弹出 + sift-down
      │
      └→ [5] Red-Black Tree
          ├→ for i=0..99: find + malloc + sglib_rbtree_add() # 插入 100 节点
          └→ sglib_rbtree_it_init_inorder + it_next          # 中序遍历, cnt += n
```

### 1.3 核心算法描述

**Array Quicksort** (SGLIB 宏展开):
- 非递归快排，用显式栈（`_startStack_[64]`/`_endStack_[64]`）
- 双指针分区（Lomuto 风格）
- 数据: 100 个 int，预定义乱序

**Doubly Linked List Sort** (`sglib_dllist_sort`):
- 自底向上归并排序（merge sort）
- 初始步长 1，每轮翻倍，直到覆盖全部
- 比较函数: `e1->i - e2->i`

**Heap Operations** (SGLIB 宏展开):
- 数组实现的二叉堆
- `HEAP_ADD`: sift-up (O(log n))
- `HEAP_DELETE`: 替换堆顶 + sift-down (O(log n))
- 总计 200 次堆操作（100 add + 100 delete）

**Red-Black Tree** (`sglib_rbtree_add`):
- 递归插入 + 旋转平衡
- `sglib___rbtree_add_recursive`: 比较 → 递归左/右子树 → 检查红黑性质 → 旋转

### 1.4 循环结构

| 循环层 | 变量/操作 | Trip Count | 说明 |
|--------|----------|-----------|------|
| benchmark_body 外层 | lsf_cnt | 31 (+1 warmup) | LOCAL_SCALE_FACTOR |
| **Quicksort 分区** | left/right scan | ~O(n log n) | 100 个元素, ~650 次比较 |
| **DL List 插入** | i | 100 | 头插入 O(1) × 100 |
| **DL List 排序** | 归并 passes | ~7 passes | log2(100) ≈ 7, merge sort |
| **Hash 查找+插入** | i | 100 | 链表查找 + 头插 |
| **Heap sift-up** | 100 次 | O(log n) each | 平均 ~3-4 层 |
| **Heap sift-down** | 100 次 | O(log n) each | 平均 ~3-4 层 |
| **RB Tree 插入** | 100 次 | O(log n) each | 递归 + 旋转 |
| **RB Tree 中序遍历** | 100 次 | O(1) amortized | 迭代器 |

### 1.5 访存模式

| 数据结构 | 大小 | 访问模式 | 说明 |
|----------|------|---------|------|
| array2[100] | 400B | 随机读写 (quicksort 分区) | 全驻 L1D |
| dllist 节点 × 100 | 100×24B = 2.4KB | 链表指针追逐 | malloc_beebs 分配, 连续内存 |
| htab[20] + ilist 节点 × 100 | 160B + 1.6KB | 哈希桶 + 链表追逐 | 随机桶选择 |
| 堆数组 a[101] | 404B | 数组 sift up/down | 全驻 L1D |
| rbtree 节点 × 100 | 100×24B = 2.4KB | 指针追逐 (左/右子树) | 树深 ~7 层 |

**数据总量**: ~7.4KB → **完全驻 L1D**

### 1.6 计算特征

- **指针追逐密集型**: DL List sort、RB Tree、Hash Table 都大量使用指针追逐 (`ld ptr → ld [ptr]`)
- **运算类型**: 整数比较 (`lw` + `subw` + `blt/bge`) + 指针操作 (`ld`/`sd`)
- **分支特征**: 数据相关分支密集，比较结果取决于输入数据 → **分支预测难度高**
- **递归**: RB Tree 插入使用递归，产生函数调用开销
- **混合工作负载**: 5 种不同的数据结构交替使用，I-cache 和 D-cache 工作集变化

## 2. 汇编热点分析

### 2.1 Spike 执行概况
```
Total instructions: 2,490,916
Cycles:  2,490,913
Instret: 2,490,916
IPC: 1.0000 (spike 顺序执行)
```

### 2.2 核心函数反汇编

**Quicksort 分区内层循环** (left scan, 0x10884-0x1088a):

```asm
# === 从左向右扫描: while (a[a5] <= pivot) a5++ ===
10884:  lw    t4,0(a4)           # t4 = array2[a5]
10888:  addi  a4,a4,4            # a4 指针 += 4
1088a:  bge   a7,t4,1087e        # if (pivot >= a[a5]) → 继续扫描
```

**Quicksort 分区内层循环** (right scan, 0x10894-0x1089e):

```asm
# === 从右向左扫描: while (a[a3] > pivot) a3-- ===
10894:  lw    a4,0(a0)           # a4 = array2[a3]
10896:  addi  a0,a0,-4           # a0 指针 -= 4
10898:  blt   a4,a7,1090a        # if (a[a3] < pivot) → partition done
1089c:  addiw a3,a3,-1           # a3-- (index)
1089e:  bge   a3,a5,10894        # if (right >= left) → 继续扫描
```

**DL List 归并排序** (`sglib_dllist_sort`, 0x105d0-0x1060a):

```asm
# === merge: 比较两个链表头节点 ===
105d0:  lw    a1,0(a3)           # a1 = list1->i
105d2:  lw    a4,0(a5)           # a4 = list2->i
105d4:  blt   a1,a4,1060a        # if (list1->i < list2->i) → take list1

# === take list2 ===
105d8:  sd    a5,0(a2)           # *tail = list2
105da:  addi  a2,a5,8            # tail = &list2->next
105de:  ld    a5,8(a5)           # list2 = list2->next
105e0:  snez  a4,a5              # a4 = (list2 != NULL)
105e4:  bnez  a4,105d0           # if (list2 valid) → continue merge

# === take list1 ===
1060a:  sd    a3,0(a2)           # *tail = list1
1060c:  addi  a2,a3,8            # tail = &list1->next
10610:  ld    a3,8(a3)           # list1 = list1->next
10612:  snez  a4,a3              # a4 = (list1 != NULL)
10616:  bnez  a4,105d0           # if (list1 valid) → continue merge
```

**Heap sift-down** (0x10bd2-0x10c0c):

```asm
# === SGLIB___ARRAY_HEAP_DOWN: 堆下沉操作 ===
10bd2:  slli  a5,a1,0x1          # a5 = 2*i (left child index)
10bd6:  addiw a5,a5,1            # a5 = 2*i+1
10bd8:  bge   a5,a0,10bbe        # if (left >= max) → done

10bdc:  slli  a6,a1,0x2          # a6 = i*4 (byte offset)
10be0:  slli  a2,a5,0x2          # a2 = left*4
10be4:  add   a2,a2,s10          # a2 = &a[left]
10be6:  add   a7,s10,a6          # a7 = &a[i]
10bea:  lw    t1,0(a2)           # t1 = a[left]
10bee:  lw    a7,0(a7)           # a7 = a[i]
10bf2:  slli  a2,a1,0x1          # right = 2*i+2
10bf6:  addiw a2,a2,2            # 
10bf8:  blt   a7,t1,10c2e        # if (a[i] < a[left]) → m = left

10bfc:  bge   a2,a0,10bbe        # if (right >= max) → done
10c00:  slli  a5,a2,0x2          # a5 = right*4
10c04:  add   a5,a5,s10          # a5 = &a[right]
10c06:  lw    a5,0(a5)           # a5 = a[right]
10c08:  blt   a5,a7,10bbe        # if (a[right] < a[i]) → done
10c0c:  bge   a7,a5,10bbe        # if (a[i] >= a[right]) → done
```

**RB Tree 递归插入** (`sglib___rbtree_add_recursive`, 0x10426-0x1057c):

```asm
# === 比较 + 递归 ===
10426:  ld    a5,0(a0)           # a5 = *tree (当前节点)
10428:  beqz  a5,1045c           # if (NULL) → 插入新节点
1042a:  lw    a4,0(a1)           # a4 = new->n (待插入值)
1042c:  lw    a3,0(a5)           # a3 = node->n (当前节点值)
10434:  subw  a4,a4,a3           # a4 = cmp(new, node)
10438:  bltz  a4,10442           # if (new < node) → 左子树
10442:  addi  a0,a5,8            # a0 = &node->left
10448:  jal   ra,10426           # 递归 (left)
...
104b4:  addi  a0,a5,16           # a0 = &node->right
104ba:  jal   ra,10426           # 递归 (right)

# === 红黑平衡检查 + 旋转 ===
10466:  ld    a5,0(s0)           # a5 = *tree
10468:  ld    a4,8(a5)           # a4 = node->left
1046a:  ld    a3,16(a5)          # a3 = node->right
1046c:  lbu   a2,4(a4)           # a2 = left->color
...                               # 检查红黑性质, 条件旋转
```

### 2.3 热点 PC 分布

| 区域 | 函数 | 总执行次数 | 占比 |
|------|------|-----------|------|
| **RB Tree 递归插入** | `sglib___rbtree_add_recursive` | 553,804 | 21.4% |
| **Heap ops + RB Tree 构建** | `benchmark_body` (0x10bc0-0x10ca2) | 547,392 | 21.1% |
| **DL List 归并排序** | `sglib_dllist_sort` | 342,336 | 13.2% |
| **RB Tree 中序遍历** | `sglib__rbtree_it_compute_current_elem` | 336,448 | 13.0% |
| **Quicksort 分区** | `benchmark_body` (0x10840-0x109a8) | 238,848 | 9.2% |
| **Queue + Heap 宏** | `benchmark_body` (0x10b20-0x10bc0) | 147,072 | 5.7% |
| **DL List 构建** | `benchmark_body` (0x109a8-0x10a80) | 135,840 | 5.2% |
| **malloc_beebs** | `malloc_beebs` | 134,400 | 5.2% |
| **Hash Table** | `benchmark_body` (0x10a80-0x10b20) | 102,080 | 3.9% |
| RB Tree 遍历累加 | `benchmark_body` (0x10ca2-0x10d42) | 26,306 | 1.0% |
| 其他 (pk/bbl + memcpy) | — | 26,973 | 1.0% |
| **合计** | — | **~2,591,499** | **100%** |

**执行次数验证**:
- malloc_beebs 调用: 100(DL) + 100(Hash) + 100(RBT) = 300 次/迭代 × 32 = 9600 次
- malloc_beebs 134400 指令 / 9600 调用 ≈ 14 条/调用 ✓

### 2.4 微架构分析

**Quicksort 分区（left scan, 3 条/iter）**:
```
lw t4,0(a4) ──→ bge a7,t4  (data-dependent branch)
addi a4,a4,4               (loop pointer, 1 cycle)
```
- 延迟: lw(2) + branch(1) = 3 cycles/iter，3 条指令 → IPC ≈ 1.0
- **瓶颈**: lw→branch 是串行依赖，且分支结果依赖加载数据 → **分支预测关键**

**DL List 归并（6 条/iter）**:
```
lw a1,0(a3) ──┐
               ├──→ blt a1,a4  (比较, data-dependent branch)
lw a4,0(a5) ──┘
sd a5,0(a2) ──→ ld a5,8(a5)  (pointer chase: store→next load)
```
- 延迟: lw(2) + branch(1) = 3 cycles（比较链），ld(2) + ld(2) = 4 cycles（指针链）
- **瓶颈**: 指针追逐 `ld a5,8(a5)` → 下一次 `lw 0(a5)` 形成串行依赖链

**RB Tree 递归插入（~10 条/递归层）**:
```
ld a5,0(a0) ──→ lw a4,0(a1) + lw a3,0(a5) ──→ subw ──→ bltz ──→ jal(递归)
```
- 每层递归: ld(2) + lw(2) + subw(1) + branch(1) + jal(1) ≈ 7 cycles
- 树深 ~7 层 → 每次插入 ~50 cycles + 旋转开销
- **瓶颈**: 指针追逐 (`ld a5,0(a0)`) + 递归调用开销

**Heap sift-down（~12 条/sift-step）**:
```
slli ──→ add ──→ lw t1 ──┐
                          ├──→ blt (比较)
slli ──→ add ──→ lw a7 ──┘
```
- 延迟: slli(1) + add(1) + lw(2) = 4 cycles/比较
- 每次 sift-down ~log2(100) ≈ 7 步

**整体分支预测困难度分析**:
| 算法 | 分支可预测性 | 原因 |
|------|-------------|------|
| Quicksort 分区 | **低** | 比较结果取决于随机数据 |
| DL List 归并 | **中** | 两个有序链表合并，局部可预测 |
| Heap sift-down | **中** | 堆序性质提供一定规律 |
| RB Tree 插入 | **低** | 树结构和数据决定左/右子树选择 |
| Hash 查找 | **低** | 链表长度不均，提前终止条件随机 |

**预计 IPC (OoO core)**:
- Quicksort 分区: 1.0~1.5（数据相关分支 + 小循环体）
- DL List sort: 0.8~1.2（指针追逐限制 MLP）
- RB Tree: 0.5~1.0（递归 + 指针追逐 + 分支误预测）
- Heap ops: 1.0~1.5（数组访问，地址可计算）
- **加权平均**: ~0.8~1.2（指针追逐和分支预测是主要瓶颈）

## 3. 总结

```
算法:           5 种数据结构综合测试 (quicksort, DL list, hash table, heap, RB tree)
数据量:         ~7.4KB (100 个 int + 300 个链表/树节点, 全驻 L1D)
计算类型:       指针追逐 + 数据相关分支 密集
热点分布:       RB Tree 34.4%, DL List 18.4%, Heap 26.8%, Quicksort 9.2%
瓶颈预测:       pointer-chase bound + branch misprediction bound
分支特征:       大量数据相关条件分支, 预测难度高
特殊说明:       递归 RB Tree 插入产生额外函数调用开销; 5 种算法交替执行增加 I-cache 压力
```
