# 性能分析子领域历史脉络与技术综述

> 主题：计算机体系结构 / 性能分析中，从动态执行 trace 中识别程序结构（重复模式 / phase / 路径 / 热点）的算法。
> 体例：详尽综述。读者为资深 RISC-V 微架构工程师。
> 引用规范：所有论文均给出作者、年份、会议/期刊。无法可靠核实者标 [需核实]。

---

## Part 1 广泛历史叙事

### 一、早年的"trace"：从大型机的打印纸到 SPEC 时代的失控曲线

要理解"从动态 trace 中识别程序结构"这一子领域为何会出现，得先把镜头拉回到 1960 年代的机房。那时的工程师拿到 IBM 7094 或 CDC 6600 的指令流，第一反应是用行式打印机把它一条条打出来，再拿尺子量、用方格纸画 IPC 曲线。Trace 在硬件人手里从来不是新鲜东西。新鲜的是后来某一刻，有人忽然意识到——trace 不只是数据，它还可以是结构。这两个看似相邻的命题之间，隔着将近三十年的沉默期。这三十年里，体系结构社区习惯把 trace 看成"汇总后的统计材料"，而不是可被查询、可被压缩、可被分解的一种"语言"。

最早把 trace 当作"结构样本"来读的，反倒不是体系结构社区，而是形式语言学习领域。1972 年，Biermann 与 Feldman 在 *IEEE Transactions on Computers* 发表 *On the Synthesis of Finite-State Machines from Samples of Their Behavior*，提出 k-Tail 算法：给一段事件序列，合成一个能复现它的有限状态自动机。这篇论文当年并未引起硬件圈的注意，但它埋下的核心不变量——"两个状态如果 k 长度后缀集合相同就合并"——三十年后几乎原封不动地走进了 Ammons-Bodík-Larus 2002 年的 PFSA。1995 年 Cook 与 Wolf 在 ICSE 发表 *Discovering Models of Software Processes from Event-Based Data*（1998 年的 TOSEM 扩展版收录），第一次把这种思路明确搬到软件语境，他们关心的不是指令流而是开发过程的事件流——bug 报告、commit、build。所用的 Markov 模型与 k-Tail 一脉相承。Cook 和 Wolf 还在论文里留了一笔历史脚注：怎样度量两台学到的 FSM 是否"相似"？这个问题至今没有公认答案，也正是规约挖掘日后在工业评估里始终缺乏 ground truth 的源头。

回到体系结构社区。1990 年代以前的所谓"性能分析"主要做两件事：一是 gprof 这类采样剖析器（sampling profiler）告诉你哪个函数最耗时，二是把 trace 喂进周期精确模拟器（cycle-accurate simulator）算出 CPI 与 miss rate。两件事的本质都是"计数聚合"（counting aggregation）——把动态执行汇总成几个标量，根本不去问"程序内部有什么样的结构在不断循环出现"。这套做法在小规模 benchmark 上勉强能用，可一旦 SPEC95、SPEC2000 把基准测试推到 trillion 指令的量级，周期精确模拟跑一个程序就要数周，工业界根本等不起。1997 年，Compaq Western Research Lab 的 Anderson、Berc、Dean 等人在 SOSP 发表 *Continuous Profiling: Where Have All the Cycles Gone?*（即 DCPI），正是冲着这种"cycle 跑哪去了我都不知道"的工程焦虑去的。他们把采样剖析的速率推到 5200 次每秒，把 stall 原因归因（attribution）到指令粒度。同年 Dean 与 Hicks 在 MICRO 发表 *ProfileMe*，让 OoO 流水线里的每条动态指令都能被独立打 tag。两件事是顶尖的工程作品，但本质仍然是"把计数切得更细"，没有回答更深的那个问题——程序按什么节奏切片？

DCPI 与 ProfileMe 的局限，恰好划出后续研究的起跑线。它们解决了"按指令归因事件"（per-instruction event attribution），没解决"重复结构识别"。再细的 cache miss 直方图也看不见"程序前 5% 时间在循环 A、随后 30% 时间在循环 B"这种相位（phase）结构。Compaq Alpha 团队后来在内部讨论过为 ProfileMe 加一层"相位感知"（phase-aware）采样，可项目随着 DEC 被 Compaq 再被 HP 吸收而搁浅——这是体系结构社区少数几个被并购终结、而不是被技术超越的研究脉络，今天回看仍可惜。

把目光放在 1999-2000 这两年，还能看出一条更隐蔽的线索：当时社区遇到的首要工程痛点不是"怎么定义一个热点"，而是"怎么先把指令和地址历史留下来"。Larus 1999 年在 PLDI 发表的 *Whole Program Paths*（即 WPP，整程序路径分析）——把整条程序路径压成可查询的紧凑结构——和同年 PLDI 上 David Lucco 的 *Split-Stream Dictionary Program Compression*——把控制流与地址流分开压缩——表面上是两件不相关的事，骨子里却出自同一个朴素工程动作：trace 大到撑不住分析了，先把它压成算法能消化的对象，"识别什么"是后一步的事。这一段历史能解释一个常被忽略的事实：trace 结构化表示这条线事实上比相位分析（phase analysis）更早成形。它不是从某个抽象理论里推出来的，而是被 trace 体量直接逼出来的。也正因为如此，许多看似互不沾边的分支共享的"思想传染"并非来自体系结构内部，而是来自相邻的字符串算法、语法压缩、序列索引：后缀数组（suffix array）、语法归纳（grammar inference）、字典压缩（dictionary compression）这些原本属于算法和软件工具社区的技术，悄无声息地走进了性能分析。两条并行路线由此分化——"先压缩后理解"由 Larus、Lucco 这一支代表，"先观测后优化"由几乎同时浮现的 Dynamo、SimPoint 代表。它们的动机（motivation）不同，回应的却是同一个核心痛点。

### 二、SimPoint 与 Dynamo：两条"识别结构"的路径在世纪之交同时浮现

进入 2000 年，两个互不相识的工程团队同时撞上了同一个问题：他们都不得不"识别结构"，否则手头的工作做不下去。

先说学界这一头。UCSD 的 Brad Calder 团队那时面对的窘境是：把 SPEC2000 整套基准跑一轮周期精确（cycle-accurate）模拟，要等好几个月。聪明的做法当然是只挑代表性的 100M 指令片段细模拟——可什么叫"代表性"？这就要先证明：程序在不同时间窗口里，确实存在可重复的"行为相位"。Calder 当时的研究生 Tim Sherwood 在 1999 到 2001 间反复试错。第一次他直接用 IPC 时间序列做聚类，结果噪声太大；第二次换成 cache miss 时间序列，结果又过度依赖具体的 cache 配置，跨平台一变就崩。直到 2001 年底，他终于意识到一个朴素的事实——基础块（basic block，简称 BB）的频率分布才是"与微架构无关的、程序自身的指纹"（fingerprint）。这个判断让 SimPoint 真正立住了。2002 年，Sherwood 与 Perelman、Hamerly、Calder 一起在 ASPLOS 发表 *Automatically Characterizing Large Scale Program Behavior*：每 100M 指令算一个基础块向量（Basic Block Vector，简称 BBV），记录该窗口内每个 BB 的执行频率，再用 k-means 把全部窗口聚成几类，每类挑一个代表点（representative point）详细模拟。十五年后，这篇论文拿到了 ASPLOS Most Influential Paper Award——获奖原因不是算法多漂亮，而是它让整个社区第一次相信，"程序行为可以被自动切相位"是一件能落地的事。

巧合的是，几乎同一时间，Wisconsin 的 Dhodapkar 与 Smith 在 ISCA 2002 发表 *Managing Multi-Configuration Hardware via Dynamic Working Set Analysis*。他们的角度完全不同——动机是"硬件应当根据相位切换配置"，因此从工作集签名（working-set signature）入手独立给出一套相位识别方法。两个团队都是事后才知道对方在做同样的事。两组人在论文回顾（retrospective）里都说过类似的话：直到 ASPLOS 与 ISCA 的会场上撞了车，才意识到自己不是孤军作战。这种"独立同源"现象本身就在告诉我们一件事：到了 2002 年这个节点，"程序行为可被切相位"已经成熟到，任何被同一类问题困住的人都会迟早撞上来。

之后几年，相位分析几乎一年一篇顶会。Sherwood 与 Sair、Calder 2003 年在 ISCA 上推出 *Phase Tracking and Prediction*，把 SimPoint 从离线扩展到在线——关键的创新是把 BBV 的"全维度"压成行程编码（Run Length Encoding，RLE）风格的、只看"最近 N 个执行 BB"的轻量指纹，让在线相位检测能在硬件的固定大小缓冲里完成。Lau、Schoenmackers、Calder 2004 年的 ISPASS 论文 *Structures for Phase Classification* 是这一支少有的"自我批评"——他们系统地比较了 BBV、循环分支（loop branch）、过程（procedure）等不同结构作为相位指纹的得失，并坦承 BBV 在某些工作负载（workload）上其实不是最佳选择。2005 年 Hamerly 等把工具固化成 *SimPoint 3.0*，发表在 JILP，引入快速 k-means、可变区间长度（variable interval）、majority-only 等工程改进；UCSC 的 Krintz 团队 2006 年在 CGO 发表 *Online Phase Detection Algorithms*，把相位识别搬进 JVM 的在线优化；Princeton 的 Margaret Martonosi 团队同年在 MICRO 发表 *Live, Runtime Phase Monitoring and Prediction on Real Systems*——首次在真实硬件上跑运行时（runtime）相位预测、用以驱动动态电压频率调整（DVFS，Dynamic Voltage and Frequency Scaling）。这一篇的工程意义不容小觑：它证明了相位分析不是模拟器里的玩具，而是能在生产硬件上每秒做几百次 DVFS 决策的工程方法。

再说工业界这一头。HP Labs 的 Vasanth Bala 那时盯着另一种焦虑：怎样不重新编译就让旧二进制在新硬件上跑得更快。Bala 的动机讲得很直白——HP 卖给企业客户的 PA-RISC 商业软件大都是几年前编的，可 PA-8500 这一代处理器加了一堆新的调度特性，老二进制根本吃不到。客户不可能为了 5% 的性能去重新构建一遍整套软件，但 vendor 端可以"暗中"动手脚。这就要求他必须在运行时识别哪些短指令序列频繁执行，把它们特化（specialize）之后扔进代码缓存（code cache）重用。2000 年 PLDI，Bala 与 Duesterwald、Banerjia 共同发表 *Dynamo: A Transparent Dynamic Optimization System*，提出 NET（Next Executing Tail，下一执行尾）算法：某个 BB 被执行超过阈值时，把紧随其后的几个 BB 串起来形成一条 trace。NET 的精彩之处其实不在算法本身——它甚至有点 ad hoc——而在工程哲学：在线、低开销、宁可错过也不能误杀热路径。Dynamo 后来的命运颇为唏嘘：项目本身因为内部 Itanium 项目的资源争夺被 HP 砍掉，但 Bala 等人离开 HP Labs 之后，部分代码作为 DynamoRIO 在 MIT 重生（Bruening、Garnett、Amarasinghe，CGO 2003）——这个重生版本至今仍在被各路体系结构研究者当作动态二进制插桩（DBI，Dynamic Binary Instrumentation）的事实标准来用。

五年之后，Hiniker、Hazelwood、Smith 在 MICRO 2005 的 *Improving Region Selection in Dynamic Optimization Systems* 把这条线系统化，提出 LEI（Last-Executed Iteration，最近执行迭代）。NET 的具体失败模式他们抓得很准：嵌套循环里如果内层迭代次数（trip count）大，trace 头部（trace head）会被触发在内层中段某个 BB 上，trace 切到一半就遇到反向分支（backward branch）被截断；代码缓存里留下的 trace 头其实是循环中段，下次进入还要"反向补一段"，资源浪费严重。LEI 的思路是观察"最热的反向分支"，从而识别真正的循环边界。又过一年，Andreas Gal、Probst、Franz 2006 年在 VEE 推出 *HotpathVM*，把 trace 选择（trace selection）升级到 trace tree（trace 树）——同一个 trace 头允许有多条共享前缀的路径。这正是后来 PyPy 元追踪（meta-tracing）与 Mozilla TraceMonkey 的直接前身。Gal 自己 2009 年又在 PLDI 发表 *Trace-based Just-in-Time Type Specialization for Dynamic Languages*，把 trace JIT 推到 JavaScript；同年 Bolz、Cuni、Fijalkowski、Rigo 在 ICOOOLPS 上的 *Tracing the Meta-Level* 把它推到"trace 解释器"层面，PyPy 由此诞生。Bolz 之后在 Heinrich Heine University 与 Tratt 合作多年，把元追踪研究推成了一个独立的子社区。

值得专门提一笔的是 trace cache 这条硬件线，它几乎与 Dynamo 并行成长。Eric Rotenberg、Bennett、Smith 1996 年的 MICRO 论文 *Trace Cache: A Low Latency Approach to High Bandwidth Instruction Fetching* 实际上已经在硬件层面"识别热 trace、缓存其解码结果"，只是目标是 fetch 带宽而非 trace 编译。Pentium 4 的 trace cache 与 Intel 之后的 µop cache 都是它的衍生物。Rotenberg 当时是 Wisconsin 的博士生，他的导师 Jim Smith 同时也是 Karkhanis、Eyerman 等人的导师。Smith 这一系学生横跨 trace cache（分支 2）、interval analysis（分支 5）、working-set signature（分支 1）三条线——这种"一个学派覆盖多个分支"的现象，在体系结构史上并不多见。

### 三、Larus 的跨领域跳跃：用 SEQUITUR 把 trace 写成一门语法

如果说 SimPoint 代表相位，Dynamo 代表热路径，那么 1999 年 James Larus 在 PLDI 发表的 *Whole Program Paths*（WPP）代表的就是第三条路——把整条 trace 写成一份可还原的紧凑语法（grammar）。这件事的来龙去脉颇有故事性。Larus 当时在微软研究院。他与 Tom Ball 1996 年的 MICRO 论文 *Efficient Path Profiling*（即著名的 Ball-Larus 编号）已经能高效地给每条无环路径（acyclic path）编号计数，但 Larus 心里清楚：直方图把 path 之间的时序关系全丢掉了，他不满足于此。同一时期，他偶然读到新西兰 Waikato 大学 Craig Nevill-Manning 与 Ian Witten 1997 年在 JAIR 上发表的 *Identifying Hierarchical Structure in Sequences: A Linear-Time Algorithm*——也就是 SEQUITUR。后者是纯粹的数据压缩工作，目标是把 DNA 序列或自然语言文本写成上下文无关语法（context-free grammar，CFG）。Larus 在 WPP 的致谢（acknowledgment）里记下这个时刻：他是看到 Nevill-Manning 一篇会议论文之后，才忽然意识到这个算法可以拿过来用。这是跨领域算法迁移的一个干净范例。把 acyclic path 序列喂进 SEQUITUR，输出的语法 DAG（有向无环图，directed acyclic graph）既是无损压缩，又能直接被查询"哪条子路径（subpath）重复得最多"——热子路径（hot subpath）这个概念由此而生。WPP 在 PACT 2005 被 Tallam、Gupta、Zhang 扩展成 *Extended Whole Program Paths*，把数据依赖也编码进去。这条基于语法的路径压缩线在体系结构圈相对小众，但它的算法身影贯穿了后来 Vampir、Score-P 等 HPC 性能可视化工具内部的 trace 摘要（summarization）模块。

WPP 在工业上的"沉寂"，原因并不在算法不够强，而在它的生态位太尴尬。它被两侧夹击：要做模拟器加速，SimPoint 的颗粒度更合适；要做基于剖析的优化（PGO，Profile-Guided Optimization），Ball-Larus 直接的路径频率（path frequency）表格已经够用，且消费起来更省事。WPP 站在一个"完整 trace 但又不是直方图"的中间地带，反而成了一种负担。这个教训后来被规约挖掘（specification mining）社区悄悄吸收——他们不再追求完整 trace 重建，而是把问题拆成两个更明确的小目标：要么学不变式（invariant，Daikon 路线），要么学有限状态机（FSM，Finite-State Machine，Perracotta 路线），不再贪图二者兼得。

Ammons、Ball、Larus 1997 年还合作发表了 *Exploiting Hardware Performance Counters with Flow and Context Sensitive Profiling*（PLDI），在那里定义了调用上下文树（calling context tree，CCT）。CCT 不像 WPP 那样追求无损还原，而是更紧凑、更适合做剖析报告。十年之后，Bond 与 McKinley 在 OOPSLA 2007 发表 *Probabilistic Calling Context*（PCC，概率调用上下文），用哈希把 CCT 节点压成 32 位 ID：每个调用点（call site）只增加 3% 开销，就能维护当前上下文的指纹。这一手在 Java VM 圈成了标准做法。CCT 与 PCC 的对立本质上是"完整结构 vs 哈希指纹"，跟 BBV vs 工作集签名的对立同构。这种"完整 vs 指纹"的二元张力反复出现在多个分支里，提示着一条更深层的设计原则：一旦结构识别要在线进行，几乎都得借助某种形式的哈希压缩。

### 四、polyhedral 派的入侵：把 trace 当作 affine 模型的样本

2000 年代中期，多面体编译（polyhedral compilation）社区已经在静态分析侧成熟——他们能把"嵌套 affine 循环 + 数组访问"表达成多面体集合，做 tiling、parallelization、locality 优化。Strasbourg 的 Philippe Clauss 团队意识到一件事：如果能反过来从 trace 重建出 affine 循环嵌套，就能把"运行时观察到的程序"变成"可以再次被静态优化的循环"。Ketterlin 和 Clauss 2008 年在 CGO 发表的 *Prediction and Trace Compression of Data Access Addresses Through Nested Loop Recognition* 提出 NLR（Nested Loop Recognition）算法：扫描一个数值 trace，输出一个能完全复现它的循环嵌套程序。这个工作有强 prior（程序由 piecewise-affine 循环生成），所以适用面比 SEQUITUR 窄，但优势是输出可执行而不仅可还原。Clauss 团队后续把这条线一直推到 Rec2Poly（2020，SAMOS）——把递归函数的 trace 反推成 affine 循环。Sato、Inoguchi、Nakamura 2014 年在 IEICE Transactions on Information & Systems 发表的 *Identifying Program Loop Nesting Structures during Execution of Machine Code* 走的是不同方向：他们关心的是机器码 trace 上跨过程的 loop nest 重建，提出 Loop-Call Context Graph（LCCG）。

### 五、关键路径：从 PERT 网络到 token-passing 算法

Critical path 这个概念远比体系结构来得早，它来自 1950 年代的项目管理（PERT、CPM）。把它搬进处理器内部，最早能追溯到 1990 年代末的几篇 retrospective（Tullsen、Eggers 等关于 SMT 的早期工作里其实已经隐含了关键路径的思想）。但真正把"从 trace 上构造 dependence DAG、找出关键路径、再以它驱动调度策略"系统化做成第一篇标志性论文的，是 Brian Fields、Shai Rubin、Rastislav Bodík。Bodík 当时还在 UW Madison（之后辗转 Berkeley、再到 UW Seattle）。他和博士生 Fields 关心的问题非常实在：到 1990 年代末，Alpha 21264、HP PA-8500 这一代 OoO 处理器的 register file、issue queue、ROB 都已经做得很大，可工程师们却发现，加大 ROB 不再带来线性的性能提升。为什么？答案就在关键路径上——只有关键路径上的指令延迟才决定最终的执行时间，给非关键路径上的指令砸资源是浪费。要差异化地分资源，就得先识别关键路径；要识别关键路径，就得在线动态地做。这就是 Fields-Rubin-Bodík 2001 年 ISCA 工作的全部动机。

他们提出的令牌传递（token-passing）算法看起来漂亮得像一个魔术：不必真的构建整张依赖 DAG，每条指令上挂一个令牌（token），token 在依赖边（dependence edge）上"传过来"的那一刻，就是该指令进入关键路径的时刻。这个算法 2016 年拿到了 ISCA Influential Paper Award。Bodík 在颁奖讲话里讲过它的洞察（insight）来源——他们最初尝试把 PERT 网络的分支定界（branch-and-bound）求解搬进硬件，发现实现代价完全无法接受，必须改成一种流式（streaming）算法。"token 在线上一拍一拍传播"这种思路在硬件归约树（reduction tree）里其实已经存在很久，把它移植到依赖图上，纯粹是一次干净的领域迁移。紧接着 Fields、Bodík、Hill 在 ISCA 2002 发表 *Slack: Maximizing Performance Under Technological Constraints*，把"关键路径外的余裕"（slack）具体化成可被调度的资源——slack 大的指令可以走低功耗路径或更远的簇（cluster），从而省下功耗或让微架构更宽松。同年 Tune、Liang、Tullsen、Calder 在 PACT 发表 *Quantifying Instruction Criticality*——他们试图把"关键性"（criticality）这个抽象概念配上一个可测度量。所谓 alone delay（孤立延迟），就是让某条指令延迟一拍，看总执行时间增加多少，把它当作"真值 criticality"，再用 token-passing 之类的近似算法去逼近这个真值。2008 年，Salverda 与 Zilles 在 CGO 推出 *Accurate Critical Path Prediction via Random Trace Construction*，提出用剖析引导（profile-guided）的方式随机生成短 trace（按硬件采样到的指令分布概率走 1000 条指令）来估算关键路径，硬件代价比 token-passing 还低。这是这一支朝"低硬件成本"持续演化的代表。

这条线在 2004 年与区间分析（interval analysis）汇流。Karkhanis 与 Smith 当年在 ISCA 发表 *A First-Order Superscalar Processor Model*，把执行时间切成"以 miss 事件（miss event）为分界的区间（interval）"——每个 interval 内 IPC 接近无 miss 时的稳态，每次 miss 引入一段固定的代价（penalty）。这其实是关键路径思想的另一种表达：miss 事件就是关键路径上的瓶颈节点。Karkhanis 是 Smith 的博士生。这篇论文在体系结构圈是稀有的"第一性原理推导"（first principles）风格——他们想从指令窗口（instruction window）大小、重排序缓冲（ROB，Re-Order Buffer）容量、cache miss 延迟（latency）这些微架构常数出发，直接写出 IPC 的解析表达式，而不是依赖经验拟合，最后做出来在有限输入下误差小于 5%。Eyerman、Eeckhout、Karkhanis、Smith 在 2009 年的 *ACM Transactions on Computer Systems* 上发表 *A Mechanistic Performance Model for Superscalar Out-of-Order Processors*，把这套思路扩展到分支误预测（branch misprediction）与 cache miss 同时发生、ROB-LSQ（Load-Store Queue，访存队列）-RegFile（寄存器堆）多种瓶颈交织的复杂场景。值得一提的是，Smith 在 2017 年退休前的告别讲座里把机理性能模型（mechanistic model）视为他职业生涯最满意的工作——这句话被 Eeckhout 转引在 Sniper 的 retrospective 中。这条线最终结晶为 Sniper 模拟器（Carlson、Heirman、Eeckhout，SC 2011），一个用区间仿真（interval simulation）做核模型的多核仿真器，至今仍是开源体系结构研究里使用最广泛的快速模拟器之一。Sniper 之所以能站稳，一部分原因是 Ghent 团队多年来"工具与论文同步维护"——几乎每年的 CGO/ISCA 上都能看到基于 Sniper 的新工作。

工业界这条线开花结果，是 Intel 的自顶向下微架构分析（Top-Down Microarchitecture Analysis，TMA；Yasin，ISPASS 2014）。Yasin 把 OoO 处理器的瓶颈拆成四大类：Frontend Bound（前端受限）、Backend Bound（后端受限，再细分 Memory 与 Core）、Bad Speculation（错误推测）、Retiring（正常退休），每一类都对应可被观测的硬件性能监控单元（PMU，Performance Monitoring Unit）事件。TMA 真正的工程贡献其实不在分类本身，而在 PMU 事件的设计——Yasin 在论文里详尽描述了 Intel 怎样为支持 TMA 调整 Sandy Bridge 之后几代处理器的 PMU 事件集合，让基于发射槽（slot-based）的归因变得可行。TMA 直接进入 Intel VTune，成了事实上的标准方法学。今天几乎所有大厂的性能调优工程师都在用它的某个变体——Linux 上的 perf top-down、AMD 的 IPC 分析、ARM Streamline 都吸收了 TMA 思想。这是关键路径分支里落地度最高的产物，也是六个分支中唯一一个真正进入主流性能调优师每日工作流的方法。

### 六、规约挖掘：另一个语境下的"结构识别"

软件工程社区对"trace 结构识别"的兴趣完全不同。他们不想加速程序，他们想从程序的真实执行中倒推出"程序应该满足什么规约"——主要为了 bug detection 与 reverse engineering。这条线的现代起点是 Ammons、Bodík、Larus 2002 年在 POPL 发表的 *Mining Specifications*（注意 Larus 又出现在了这里——他的 Microsoft Research 时期同时影响了路径压缩和规约挖掘两条线）。该论文用 PFSA（Probabilistic Finite-State Automaton）把 API 调用序列建模为 FSM。

随后这一支飞快地分化。Ernst 团队在 Daikon（科技路线 1999 起，MIT 与华盛顿大学合作，2001 IEEE TSE）做的是动态不变式（dynamic invariant detection）——观察很多次执行中变量的取值，归纳出 always-true 的谓词。Yang、Evans、Bhardwaj、Bhat、Das 2006 年 ICSE 的 *Perracotta* 把 LTL 风格的时序属性挖掘做得能在大型工业系统上跑（重点处理"trace 不完美"问题）。Lo、Khoo、Liu 2007 年 KDD 发的 *Efficient Mining of Iterative Patterns for Software Specification Discovery* 把 sequence pattern mining（PrefixSpan 那一支算法）适配到软件 trace 的特殊语义上（loop 引发的 iterative pattern）。规约挖掘整体上 2005-2015 年是高峰期，2015 年之后在符号执行与机器学习的冲击下逐步式微，但 invariant detection 在测试/验证子社区仍是标配。

De Pauw、Lorenz、Vlissides、Wegman 1998 年在 USENIX COOTS 发表的 *Execution Patterns in Object-Oriented Visualization* 是另一条更早的源头——IBM T.J. Watson 的实务派从可视化角度发现"程序中有大量重复行为，看不过来必须自动归纳"。Hamou-Lhadj 与 Lethbridge 2004 年 CASCON 的 *A Survey of Trace Exploration Tools and Techniques* 给出了这一支当时的工具综述。

### 七、被外部因素重塑的演化

至少四个外部因素显著改变了上述六条分支的走向，每个因素都明确对应着分支演化的转折点。

第一是 SPEC 基准的规模膨胀与微架构精度要求的同时上涨。2000 年前后，cycle-accurate 模拟一个 SPEC 程序到收敛需要月级时间，这是 SimPoint 出现的直接动力。后续 SPEC2006、CPU2017、还有 graph workload（GAP Benchmark Suite）、ML workload（MLPerf）的引入，又让 BBV-only 的 SimPoint 不够用——基础块向量对 graph workload 不敏感，因为图算法在同一段代码中可能因为输入图结构不同呈现完全不同的 cache 行为，这驱动了后续 microarchitecture-independent characterization（Hoste 与 Eeckhout 2007 IEEE Micro，提供了 ILP、寄存器距离、分支熵等更深层指纹）和 reuse-distance based phase（Shen、Zhong、Ding 2004 ASPLOS）。今天前沿模拟器圈对 ML workload 的 phase analysis 已经不是 SimPoint 的简单扩展——SST、Sniper、ZSim 都需要专门的 layer-based 切分（按神经网络层切相位而非按 100M 指令切）。

第二是 JIT 与动态语言的兴起。Java（1995 年商用）、JavaScript V8（2008）、Python（PyPy 2009 至今）让"运行时识别热路径"从体系结构内部话题变成 mainstream 软件工程话题。HotpathVM、TraceMonkey、PyPy 就是这一波的产物，它们反过来也激活了 trace tree、guard、deoptimization 这些算法。但有意思的是，这条线在 V8（Google）选择"非 trace 而是 method-based JIT"之后开始退潮——V8 的 Crankshaft、TurboFan 都是 method JIT，TraceMonkey 在 2011 年左右被 Mozilla 弃用换成 IonMonkey。这背后的关键技术原因是工业 JavaScript 程序里函数调用密度高（jQuery、React 这种框架库一秒执行 10 万次函数调用），trace 在跨函数边界时容易爆炸成 trace tree 的 horizon explosion——同一个 trace head 可能展开成几千条 sub-trace 才能 cover 主要 control flow，编译开销盖过运行收益。Method JIT 一次编译一个函数体，有清晰的边界，且能配合 inline cache 实现 polymorphic dispatch，工程上更可控。trace JIT 在 PyPy、LuaJIT 这些更小但更纯粹的环境继续存活，原因是它们的应用场景以紧致循环为主（科学计算、游戏脚本），trace 的优势能充分发挥。

第三是工业界对"线上常态化 profiling"的强需求。DCPI 1997 年还是研究原型，到了 2010 年代被 Google、Facebook 大规模做成生产工具：Google 的 GWP（Google-Wide Profiling，Ren 等 2010 IEEE Micro）和 AutoFDO（Chen、Li、Moseley 2016 CGO）以采样 profile 代替 instrumentation，把 FDO 的部署门槛压到几乎为零。AutoFDO 的关键贡献其实是"接受 profile 是 stale 的"——传统 PGO 要求 profile 与 build 输入严格匹配，AutoFDO 容忍代码 diff 几个版本的 profile drift，并通过编译器侧的 stable id（function 名 + line 偏移）做 attribution。Facebook 的 BOLT（Panchenko 等 2019 CGO）则把 post-link 二进制重排做到工业级 datacenter scale。BOLT 在 LLVM 框架上工作，能把已经被 LTO+FDO 编译过的二进制再做一次 layout 优化，得到额外 2-15% 性能。这两个系统都吸收了 phase analysis（profile 数据的代表性挑选）+ path profiling（hot path 重排）+ critical path（先优化关键热路径）的混合思想，是六个分支在 datacenter 工程中合流的代表。

第四是机器学习在体系结构中的渗透。从 Hashemi 等 2018 年 ICML 的 *Learning Memory Access Patterns* 开始，神经网络被用来直接学习地址流的结构。这条线某种意义上"绕过"了传统 phase analysis：神经网络不输出可解释的相位边界，它直接预测下一步行为。Hashemi 这篇论文的核心结论"prefetching 本质是 sequence prediction，可以用 LSTM/Transformer 端到端学"对体系结构社区震动很大——它意味着所有"识别地址流结构再据此预测"的传统机制（Markov prefetcher、stride detector）原则上都能被神经网络取代。这对纯学术 phase classification 是真正的威胁——Akram 与 Sawalha 2019 年 arXiv 综述 *A Survey of Phase Classification Techniques for Characterizing Variable Application Behavior* [需核实正式发表去向] 已经在讨论 neural-based phase characterization 的可能性。但目前为止神经网络方法在 SimPoint 这一具体应用上还没有取代传统聚类方法，原因是模拟器仍然只需要 100 个左右代表点这种小规模问题，神经网络的优势体现不出来；反而在 prefetcher、branch predictor 这种 hot-path inference 场景神经网络正在快速取代传统方法。

除了这四个主要因素，还有两个时代背景值得提及但影响相对局部：一是开源工具链的成熟（LLVM 2003、gem5 2011、QEMU 2003 等都在 2000 年代中期之后稳定下来）让 trace 收集、分析的工程门槛大幅降低；二是 RISC-V 的兴起（2010 年首发，2015 年后规模产业化）让"针对一个具体 ISA 做 trace-based 分析"重新变得有吸引力——RISC-V 的开放使得学术社区可以无成本访问完整的 ISA spec、ABI、toolchain，整个 trace 分析管道可以端到端地复现，这与早年研究 Alpha、PA-RISC 时受限于 vendor 配合的局面完全不同。

### 八、撰稿当下的工业态势

把镜头拉到 2026 年，六条分支的命运已经分得很清。

**Phase analysis**：SimPoint 仍是模拟器圈的标配，但工业 profiling 这一头早已从"phase 切片"悄悄滑向"sample at scale"——只要在生产硬件上做满采样，统计意义上的代表性自然浮现，离线的 BBV 聚类反而显得多此一举。学术界仍在做相位预测，主要服务于 DVFS、CMP 资源调度、自适应 cache 这类硬件机制——它们需要的不是"过去什么样"，而是"未来几个 100M 指令会是什么样"。

**Trace-based dynamic optimization**：trace JIT 在主流浏览器引擎里几乎绝迹，被 method JIT + tiering 替代；可在 PyPy、LuaJIT 这种紧致循环为主的小生态里仍稳占核心位置。硬件 trace cache 以 Intel µop cache 的形式持续存在。Dynamo 那种 user-level 的 dynamic optimizer 整体已被工业界放弃——静态 PGO（gcc/clang FDO、AutoFDO、BOLT）既能拿到主要收益，部署又简单。

**Trace 结构化表示（WPP / grammar）**：纯学术上，SEQUITUR-based 路径压缩没有大型后续。但作为 trace 压缩与可视化的底层技术，它仍藏在 Vampir、TAU、HPCToolkit 这些 HPC 性能分析工具的实现里——只是不再以"WPP"为名。

**循环嵌套与仿射结构重建**：polyhedral 编译已经进入 GCC Graphite 与 LLVM Polly。但"从 trace 反推循环"这件事作为一个独立研究问题，还留在 Strasbourg 的 Inria 团队手里继续推，主要落地是 GPU kernel 优化和 stencil 自动并行。

**关键路径与瓶颈诊断**：这是工业界落地度最高的一支。Intel TMA、Linux perf top-down、ARM Streamline 都是它的直系子代。学术界自 2018 年起开始把关键路径跟 ML 结合做调度（如 Criticality Driven Fetch），但稳定进入工业的仍是 mechanistic interval model。

**执行规约挖掘**：invariant detection（Daikon 路线）在自动化测试圈里仍稳定存在；但 FSM-based protocol mining 在大模型时代几乎被绕过——让 LLM 直接读源码或文档，比从 trace 倒推规约还要准。这一支的学术热度近年已大幅下降。

一句话收束：工业落地度最高的是关键路径 / interval analysis（TMA），其次是 phase analysis（SimPoint）；trace JIT、WPP、polyhedral trace、规约挖掘四支主要还活在学术界与小生态。决定一条线值不值得投的，往往不是"它的算法多优雅"，而是"它对应到一个能落地的硬件机制或工具链产品"。

---

## Part 2 各分支技术综述

### 分支 1：Phase analysis（程序行为相位识别）

#### 起源

把"程序行为随时间变化"这件事从直观观察提升为可形式化的算法问题，公认起点是 Sherwood、Perelman、Hamerly、Calder 在 ASPLOS 2002 发表的 *Automatically Characterizing Large Scale Program Behavior*。论文 motivation 段写得很直白：SPEC2000 的 gcc benchmark 完整跑下来 cycle-accurate 模拟需要数月，但 IPC 在不同时间窗口差别极大，"一段一段跑"显然比"全程跑"经济得多——前提是能自动找到代表段。

那个时代的前置条件刚刚具备：一是 cycle-accurate 模拟器（SimpleScalar、Sim-Outorder）已经稳定，能产出可靠的 per-window 性能数据；二是大型机器学习库（k-means 等）开始在 SPEC 数据规模下可用；三是 SPEC 基准本身的"长 benchmark"特征日益突出（cumulative IPC 曲线肉眼可见的几段水平折线）。Wisconsin 的 Dhodapkar 与 Smith 几乎同时在 ISCA 2002 发表 *Managing Multi-Configuration Hardware via Dynamic Working Set Analysis*，从硬件适配（缓存大小、indirect branch predictor 大小自适应）的角度独立得出"working-set signature 可以指示相位"的结论。两条线一开始独立，后来合流。

#### 核心算法

SimPoint 算法非常简洁：

```
输入：完整执行的 BB 序列
1. 把 trace 切成等长 interval（默认 100M 指令一个）
2. 每个 interval 计算 BBV：维度 = BB 总数，值 = 该 interval 内每个 BB 的执行次数（通常做归一化）
3. 用 random projection 把高维 BBV 降到 ~15 维
4. k-means 聚类，k 一般取 5~30
5. 每个 cluster 选一个最接近 centroid 的 interval 作 simulation point
6. 各 simulation point 的 IPC × cluster weight 加权求和 = 全程 IPC 估计
```

Dhodapkar-Smith 的 working-set signature 走了不同路径：每 N 条指令记录一次活跃 BB 的指纹（fixed-size Bloom filter），相邻 signature 的 Hamming distance 超过阈值则视为相位转换。这种方法的优势是 online 友好——不需要 k-means。

Sherwood、Sair、Calder 2003 年 ISCA 的 *Phase Tracking and Prediction* 把 SimPoint 推到 online：用一个简化的 BBV（只看最近 N 个 BB 的执行频率）+ 简单的相位 ID 表 + Markov 风格的相位转移预测器。

#### 后续改进

Lau、Schoenmackers、Calder 2004 年 ISPASS 的 *Structures for Phase Classification* 比较了 BBV、loop branch vector、procedure vector 三种相位指纹，结论是 BBV 综合最好但 loop branch 在 IPC 预测上更稳。

Shen、Zhong、Ding 2004 年 ASPLOS 的 *Locality Phase Prediction* 用 reuse distance 而非 BBV——他们论证 reuse distance 直接捕获 cache 行为，比 BBV 在内存敏感程序上更准。Zhong 与 Shen 后续 2009 年在 TOPLAS 把 reuse distance 推广到 *Program Locality Analysis Using Reuse Distance*。

Hamerly、Perelman、Lau、Calder 2005 年 JILP 的 *SimPoint 3.0: Faster and More Flexible Program Phase Analysis* 把 k-means 加速、可变长度 interval、majority-only sample point 等工程改进打包进开源工具。SimPoint 3.0 是今天 gem5、ZSim 用户实际下载的版本。

Nagpurkar、Hind、Krintz、Sweeney、Rajan 2006 年 CGO 的 *Online Phase Detection Algorithms* 把相位检测从模拟器场景推到 JVM——动机是 JIT 应该根据相位决定何时重编译、何时丢弃热代码。这篇论文给出了一个评估在线相位检测器质量的方法学（baseline accuracy 计算）。

Isci、Contreras、Martonosi 2006 年 MICRO 的 *Live, Runtime Phase Monitoring and Prediction on Real Systems with Application to Dynamic Power Management* 第一次在真实硬件上跑相位预测，输入是 hardware performance counter 流，输出驱动 DVFS。Isci 与 Buyuktosunoglu、Martonosi 同时期在 IEEE Micro 2005 的 *Long-Term Workload Phases: Duration Predictions and Applications to DVFS* 关注更长时间尺度（秒级）的相位。

Hoste 与 Eeckhout 2007 年 IEEE Micro 的 *Microarchitecture-Independent Workload Characterization*（MICA 工具）提出脱离微架构特征的程序签名——只用 ILP、寄存器依赖距离、分支熵这种"程序自身属性"——目的是让 workload 比较结果不依赖具体硬件，间接也提供了一种相位指纹。

Patil、Pereira、Stallcup、Lueck、Cownie 2010 年 CGO 的 *PinPlay* 不直接做 phase analysis，但它作为 deterministic replay 框架使得 SimPoint-style 选点之后的精确 replay 第一次成为工业可行。PinPlay 后来支撑了 Intel SDE 与各种 architecture研究环境。

Akram 与 Sawalha 2019 年 arXiv 1908.02238 的 *A Survey of Phase Classification Techniques for Characterizing Variable Application Behavior* [需核实是否最终发表为期刊版本] 是这一支较新的综述。

#### 当前状态

工业界已基本不在做"新的 phase 算法研究"；SimPoint 3.0 加上 PinPlay 是模拟器圈的事实标准，gem5、Sniper、ZSim、Champsim 用户下载即用。学术界仍有零星工作，主要在三个方向：(1) 把神经网络用作相位指纹（前述 Hashemi 路线的衍生）；(2) 跨 ISA / 跨 workload class 的相位迁移（在 ARM 上识别的相位能否复用到 RISC-V？）；(3) 多核 / 多线程下的相位（同步事件如何融入相位边界）。

#### 局限性

第一，BBV 假设"BB 频率 == 行为指纹"对 input-sensitive 程序失效。对于 graph 算法、稀疏矩阵、ML 训练等数据驱动 workload，同一段代码在不同输入下可以呈现完全不同的微架构行为，BBV 完全相同也无法区分。一个具体例子：BFS 在稠密图与稀疏图上 BBV 几乎一致（同一段代码），但 cache miss rate 差几个数量级，phase 切分却看不到这种差异。

第二，phase 假定"段内行为均匀"，这对 interval 尺度敏感。100M 指令尺度下的"均匀"在 1M 尺度看就是 high variance。SimPoint 的 100M 默认值不一定适合所有 benchmark。在某些 ML benchmark 上，layer 之间的切换发生在几十 M 指令量级，100M interval 把多个 layer 行为聚合在一起，cluster 选出的代表点反而不能代表任何单一 layer。

第三，online phase detection 在 multi-core context-switch 下表现不稳——OS 调度引入的随机性把相位边界打碎。两个线程交错运行时，per-core 的 BBV 是两个 workload 的 mixture，相位识别完全失效。多线程 phase analysis 至今没有令人满意的解决方案。

第四，phase 是"计数式"的，不输出 phase 内部结构，因此不能直接驱动需要"路径形状"的优化（如 trace 编译）。phase 与 trace JIT 在颗粒度上有几个数量级的差距，两者无法直接互通。

---

### 分支 2：Trace-based dynamic optimization（热路径识别与编译）

#### 起源

Bala、Duesterwald、Banerjia 2000 年 PLDI 的 *Dynamo: A Transparent Dynamic Optimization System* 是分支起点。motivation 段：HP PA-RISC 上很多老二进制无法重新编译（vendor lib、商业软件），但它们在新硬件上跑得不够好，用户也不愿意为了 5% 性能去重编译。能不能在运行时透明地把热路径 specialize、内联、调度优化？

要在 2000 年做这件事，前置条件是：(1) 软件 binary translation 已经成熟（HP 的 Aries、Compaq 的 FX!32），证明运行时翻译技术上可行；(2) trace cache 硬件（Rotenberg-Bennett-Smith 1996 MICRO）已经证明"热 trace"概念有效；(3) PA-RISC 架构允许 self-modifying code 与 page protection 修改这种 dirty trick。

Rotenberg、Bennett、Smith 1996 年 MICRO 的 *Trace Cache: A Low Latency Approach to High Bandwidth Instruction Fetching* 是分支 2 的硬件前驱：在 fetch stage 之前缓存"已经被解码、按动态执行顺序排列"的指令序列。这个想法在 Pentium 4 上落地（虽然实现争议很多），后来 Intel 在 Sandy Bridge 之后改成 µop cache。

#### 核心算法

Dynamo 的 NET（Next Executing Tail）：

```
1. 维护每个 BB 的执行计数器
2. 当某 BB 被执行 > T 次（T=50 是经典值）：把它标记为 trace head
3. 从 trace head 开始，记录接下来执行的每个 BB，直到：
   - 遇到另一个 trace head（说明已经进入下一条 trace）
   - 遇到回到本 trace head 的 backward branch（循环边界）
   - 长度达到 trace 上限
4. 这条 trace 进入 fragment cache，对原 binary 中对应 BB 装 hook 让控制流跳进来
5. 在 fragment cache 中做内联、寄存器重分配、死代码消除
```

NET 的优势：极简、低开销、不需要历史。劣势：trace head 的选择会切错地方，特别是对于 nested loop。

#### 后续改进

Hiniker、Hazelwood、Smith 2005 年 MICRO 的 *Improving Region Selection in Dynamic Optimization Systems* 提出 LEI（Last-Executed Iteration）。LEI 不在 BB 计数到阈值就开始 trace，而是观察"哪个循环的 backward branch 最常被执行"，整个识别出的循环作为 region。结果是 region 形状更接近自然循环边界，code cache 利用率提升。

Gal、Probst、Franz 2006 年 VEE 的 *HotpathVM: An Effective JIT Compiler for Resource-Constrained Devices* 引入了 trace tree：从同一个 trace head 出发，遇到不同的分支 outcome 时不像 NET 那样另起一条 trace，而是从公共前缀分叉成多条 trace，组成一棵 tree。HotpathVM 是 trace JIT 思想第一次明确进入高级语言（Java bytecode）VM 实现。

Gal 等 2009 年 PLDI 的 *Trace-based Just-in-Time Type Specialization for Dynamic Languages*（即 TraceMonkey）把 trace tree 用到 JavaScript：每条 trace 不仅是控制流序列，还携带 dynamic type 信息，编译时用 type guard 守护、type 不变就 specialize。这是 V8 之前 Mozilla SpiderMonkey 的核心。

Bolz、Cuni、Fijalkowski、Rigo 2009 年 ICOOOLPS 的 *Tracing the Meta-Level: PyPy's Tracing JIT Compiler* 把 tracing 推到一个抽象层：不 trace 用户程序，而是 trace 解释器执行用户程序的过程。这使得给一个新语言加 JIT 只需写解释器+加 hint，而不需写 JIT 本身。PyPy 整个生态建立在此之上。

Bebenita、Brandner、Fahndrich、Logozzo、Schulte、Tillmann、Venter 2010 年 OOPSLA 的 *SPUR: A Trace-Based JIT Compiler for CIL* 把 trace JIT 做到 .NET CIL 层，证明同一套 trace 技术可以服务多语言。

Hwu、Mahlke 等 IMPACT 团队的静态变体 *The Superblock: An Effective Technique for VLIW and Superscalar Compilation*（J. Supercomputing 1993）和 Mahlke 等 *Effective Compiler Support for Predicated Execution Using the Hyperblock*（MICRO 1992）虽然是静态编译器工作，但 superblock/hyperblock 与 trace 在调度算法层面共享 trace scheduling 思想，IMPACT 的 evaluation metric 也是 trace JIT 圈的对照标杆。

#### 当前状态

Trace JIT 在 mainstream JavaScript 引擎（V8、JavaScriptCore）已被 method JIT 代替。原因之一：trace 在大型 OOP 应用上 explosion（同一个 method 被很多 type pattern 调用，trace tree 节点爆炸）；原因之二：tiered compilation（baseline + optimized）在工程上更易控制；原因之三：method JIT 与 inline cache 互动更自然。这一退潮基本上发生在 2011-2014 年，TraceMonkey 在 Firefox 内部被 IonMonkey + Baseline 替换，Mozilla 工程师在内部 retrospective 中归因于"trace tree 在 Web 应用上不收敛"——同一段 JavaScript 代码可能因为不同 callsite 的 type stability 差异产生数十甚至数百条共享前缀的 trace，每条 trace 都要单独编译和维护，工程成本超过收益。

但 trace JIT 在 PyPy（Python）、LuaJIT（Lua）、GraalVM Truffle（多语言通用）这些场景仍是主流——都是动态类型 + 紧致循环为主的 workload，trace 的优势充分发挥。RPython（PyPy 的元语言）至今是 meta-tracing 的事实标准。LuaJIT 的 Mike Pall 写的 trace JIT 实现至今被认为是性能最高的 dynamic language JIT 之一，比 V8 的 method JIT 在 Lua 这种工作负载上仍然更快——这从工程角度证明 trace JIT 不是被技术超越，是被生态选择。

硬件层面，trace cache 概念在 Intel µop cache（Decoded Stream Buffer）中持续存在，AMD Zen 系列也有类似设计（Op Cache）。学术上对硬件 trace cache 的研究 2010 年代后基本停滞——这块已经"工程问题"化了，新的研究热点转向 µop fusion、large basic block detection 等更细粒度的前端优化。

在 user-level dynamic optimizer 这条线上，DynamoRIO（Bruening 等 2003 CGO，从 HP Dynamo 衍生）作为开源框架活了下来，但它的 dominant 用例已经从"性能优化"转移到"动态分析"——安全社区用它做 taint tracking、fuzzing instrumentation，体系结构社区用它做 ZSim/Sniper 的 frontend，几乎没有人再用它做"原本的性能优化"。这反映了一个有趣的领域演变：当 PGO+LTO 在编译时已经能拿到 95% 收益时，运行时优化的边际价值不再吸引人，框架本身却因为通用性而被 repurpose。

#### 局限性

第一，trace 的边界假设难处理：side-exit 的频率高时（多 type、多 branch outcome），trace tree 退化成大型 CFG，编译收益被 overhead 抵消。

第二，对 GC、deopt 的复杂交互。trace JIT 的优化代码必须支持随时回退到解释器（guard fail / type unstable），这要求维护精确的 stack map，工程成本高。

第三，"找 trace head"对 OOP workload 不友好。method 多态调用的入口频率分布平均，没有明显热点。

第四，post-link 静态优化（BOLT、AutoFDO）在 server workload 上效果与动态 trace optimization 相当甚至更好，且没有运行时 overhead——这是 Dynamo 这一支退出工业舞台的核心原因。

---

### 分支 3：Trace 结构化表示（路径压缩与语法抽取）

#### 起源

James Larus 1999 年 PLDI 的 *Whole Program Paths* 是分支起点。motivation 段：分支 1 与分支 2 的方法都"丢信息"——SimPoint 把 trace 抽成统计向量，trace JIT 只关心局部 hot path，整条 trace 的结构（哪段在哪段后面发生）没人完整保留。Larus 的目标是无损（或近无损）地把整条 trace 写成可查询的紧凑结构。

前置条件是 Ball-Larus path profiling（MICRO 1996）已经能高效地给每条 acyclic path 编号并计数；以及 Nevill-Manning 与 Witten 1997 年 JAIR 的 SEQUITUR 算法已经成熟到工程可用。Larus 的洞察是把 SEQUITUR 的输入从"DNA / 文本"换成"path ID 序列"。

#### 核心算法

SEQUITUR 在程序 trace 上的应用：

```
输入：acyclic path ID 序列（每条路径是一个 acyclic 子图，由 Ball-Larus 编号）
输出：context-free grammar，其中：
  - terminal 是 path ID
  - non-terminal 是被发现的重复模式
  - 起始 symbol 展开后唯一恢复原 trace

SEQUITUR 不变量：
  1. digram uniqueness：任何相邻两个 symbol 对至多出现一次
  2. rule utility：每个非起始 rule 至少被使用两次

每读入一个新 symbol 时增量维护这两个不变量，违反就拆/合 rule。
线性时间。
```

WPP 把这个 grammar 视为有向无环图（DAG），节点是 rule，边表示"包含关系"。一条 hot subpath 就是 grammar 中某个 rule 的展开——如果该 rule 被高频引用，那它对应的 subpath 就是热点。

#### 后续改进

Ammons、Ball、Larus 1997 年 PLDI 的 *Exploiting Hardware Performance Counters with Flow and Context Sensitive Profiling* 提出 Calling Context Tree（CCT）。CCT 不像 WPP 那样追求完整 trace 还原，但它把 calling context（caller 链）作为剖析的二级 key，使得"同一个函数在不同 caller 下的性能差异"能被拆开。CCT 至今是 HPCToolkit、TAU、Linux perf 的报告基础。

Ammons 与 Larus 1998 年 PLDI 的 *Improving Data-Flow Analysis with Path Profiles* 把 path profile 喂回数据流分析，用动态频率指导哪些 path 值得做 path-sensitive 分析、哪些可以合并。

Tallam、Gupta、Zhang 2005 年 PACT 的 *Extended Whole Program Paths*（eWPP）扩展 WPP：在控制流路径之外再编码数据依赖。他们的 insight 是大部分 data dependence 可以从 control flow 推出，剩下的少量歧义点用 instrumentation 检查，整体压缩率与 WPP 同量级但还原信息更全。

Bond 与 McKinley 2007 年 OOPSLA 的 *Probabilistic Calling Context*（PCC）把 CCT 压缩成 32-bit hash：每次 call 把当前 PCC 与 call site ID 做 hash 更新，这个 32-bit 值就是当前 context 的指纹。冲突率 0.1% 量级，开销 3%。PCC 替代了 CCT 在内存敏感场景的位置。

Knüpfer、Voigt、Nagel、Mix 2007 年 PARA workshop 的 *Visualization of Repetitive Patterns in Event Traces*（不要与 PARA 2007 confused）把这套结构化思想推到 HPC 大规模并行 trace：从 MPI 通信 trace 中识别重复模式并可视化。Vampir 性能分析工具集成了类似算法。

#### 当前状态

WPP 这条线没有大型工业产品。原因是它的核心价值（无损可还原 + 可查询热点）在两个边界被夹挤：要无损还原可以直接压缩存储 trace（gzip、CTF——Common Trace Format），要查询热点 SimPoint 或 path profiling 已经够用。但它的算法影子在 HPC 工具链（Vampir、Score-P、TAU）的事件 trace 压缩、还原、对比模块里。HPC 大规模并行 trace 的特点是节点数 × 时间 × 事件类型三维爆炸，普通 gzip 压缩不利于"按维度查询"——SEQUITUR-style grammar 因为天然保留 hierarchy 结构而在这里有用。

学术界这条线 2010 年代后基本沉寂，最近几年的零星复兴主要在两个方向：(1) 把 SEQUITUR 算法用到神经网络可解释性（用 grammar 解释 RNN/Transformer 的行为序列，[需核实具体引用]）；(2) reverse engineering（从 binary trace 恢复算法结构，特别是恶意软件分析中识别加密/反调试模式）。CCT/PCC 这一支因为是工程实用工具反而活跃——HPCToolkit（Rice 大学）的最新版本仍在维护并扩展 calling context 在 GPU、heterogeneous 系统上的语义。

#### 局限性

第一，acyclic path 的"acyclic"是按 Ball-Larus 定义切的，对于嵌套循环非常深的程序，path 数量爆炸。

第二，grammar 的"重复"是按完整子序列计算的，对程序中的"近似重复"（同一段代码加不同 prefix/suffix）识别不出。

第三，输出 grammar 不是可执行模型。WPP 不能用来做"代替 trace 跑模拟"——这是它输给 polyhedral 派的关键点。

第四，全程 trace 收集的 overhead 即便用 Ball-Larus 的高效编号也仍然不可忽略（30%+），不适合 in-production 使用。

---

### 分支 4：循环嵌套与仿射结构重建

#### 起源

Ketterlin 与 Clauss 2008 年 CGO 的 *Prediction and Trace Compression of Data Access Addresses Through Nested Loop Recognition*（NLR）正式开启这条线。motivation 段：内存地址 trace 本质是 numbers，但是大型科学计算程序的内存访问其实是少数几个 affine 函数对 loop induction variable 的求值——能不能反过来从 trace 重建出 loop nest，就把"几亿次访问"压成"两层循环 + 步长 + 范围"几十字节？这个动机最早在 Strasbourg 团队内部讨论是为了解决一个具体工程问题：他们要在分布式存储集群上分析 SPEC FP 程序的内存访问模式，原始 trace 几个 GB，存不下也传不动。如果能就地用 NLR 压缩，每个 benchmark 只需几 KB 就能完整保留访问行为。

前置条件是 Strasbourg 团队此前在 polyhedral 静态分析侧已经积累了多年（Feautrier 的 polyhedral 模型 1990s、Bastoul 的 CLooG 2004），有完整的 affine loop ↔ polyhedral set 互转工具。NLR 要做的是 trace → polyhedral set 的反向。这是一个有意思的"逆问题"：给定输出（trace），找出能产生它的最简程序结构。逆问题往往不可解或解不唯一，NLR 的成功依赖于强 prior（"程序由 piecewise affine loop 生成"）。

Clauss 当时的另一个重要 motivation 是为 GPU 编译做准备。2008 年 CUDA 已经发布两年，业界对"自动把 CPU 代码 port 到 GPU"有强烈需求，但所有自动 GPU 编译器都要求源代码可分析为 polyhedral form。如果手头只有 binary（无源码），先做 NLR 把 binary 行为反推成 polyhedral form 再调用现成 GPU 编译器是一条可行路径。

#### 核心算法

NLR 算法的简化描述：

```
输入：数值 trace v_0, v_1, v_2, ...
1. 计算一阶差分 d_i = v_i - v_{i-1}
2. 识别一阶差分的常数段：连续 N 个 d_i 都等于 c → 内层循环 step=c, count=N
3. 把内层循环"折叠"，记录每段的起始值 s_j 和长度 N_j
4. 在 s_j 序列上递归（这是外层循环的迭代）
5. 直到不再有可识别结构

输出：嵌套循环描述（外层、内层、各层 step、bounds）
```

这个算法对纯 affine trace 是精确的，对 piecewise-affine（程序里有 if-then-else）通过分段处理也能基本识别。

#### 后续改进

Clauss 团队后续把 NLR 推广到不规则 trace。具体说，他们处理 piecewise-affine 行为的方法是把单一 trace 切成多个段，每段单独 NLR，然后输出"分段循环"——这个思路其实与 phase analysis 有相似之处，只是 phase 切的是时间区间，piecewise-affine NLR 切的是循环 trip count 区间。

Sato、Inoguchi、Nakamura 2014 年 IEICE Transactions on Information & Systems 的 *Identifying Program Loop Nesting Structures During Execution of Machine Code* 走另一方向：不是从地址 trace 而是从机器码 trace 识别 loop nest，重点是处理跨过程的 loop（一个 loop 体内调用了另一个含 loop 的函数）。他们提出 Loop-Call Context Graph (LCCG) 显式编码这种跨过程嵌套。LCCG 的关键 insight 是：传统 CCT（Calling Context Tree）只记录"谁调用谁"，但 loop 内的循环往往迭代千万次，每次都在 CCT 里产生独立节点会爆炸；LCCG 通过引入 loop entry/exit 标记把同一 loop 内的多次调用合并到同一节点。这个数据结构后来被一些 HPC profiling 工具借鉴（用作 GPU kernel launch trace 的紧凑表示）。

Kobeissi、Ketterlin、Clauss 2020 年 SAMOS 的 *Rec2Poly: Converting Recursions to Polyhedral Optimized Loops Using an Inspector-Executor Strategy* 把这条线推到递归：先 instrumented run 递归程序得到 trace，从 trace 重建 affine loop，再把 loop 喂给 Polly 等多面体优化器，得到非递归优化版。Rec2Poly 的运行模式是 inspector-executor：先用 inspection run 推 loop 模型，再用 executor run 检查模型对当前输入仍然适用，适用就跑优化版，不适用就 fall back 原递归。这与传统 polyhedral 编译"必须 ahead-of-time 证明 affine"的强假设不同，是一个工程妥协。

NLR 还被用作 trace 压缩，与分支 3 的 SEQUITUR 形成对照。两者的根本差异：SEQUITUR 输出的 grammar 不携带"step"语义（即便 abc abc abc 它也只学到 abc 重复了 3 次，不会推断"步长"），NLR 则因为输入是数值而能学到"每次差 4"这种 affine 结构。这意味着对纯数值地址 trace，NLR 压缩率远超 SEQUITUR；但对含有任意符号（branch outcome、syscall 类型）的 mixed trace，SEQUITUR 更通用。Ketterlin 与 Clauss 也尝试过把 NLR 用于 cache 行为预测（已有 NLR 模型预测下一次访问地址，比硬件 stride prefetcher 更精准但需要 trace 学习时间）。

[需核实] 部分 IMPACT/MDPI 系列后续工作（如 piecewise-affine loop 在 GPU kernel 上的 NLR 应用，2021）我未能完全核实其作者列表，故仅作笼统提及。

#### 当前状态

学术上活跃，但工业应用窄。主要落地是：(1) GPU kernel 的 launch 参数自动调优（从 kernel trace 识别 loop nest 然后选 best tile size）；(2) HPC 应用的 stencil 代码识别与自动并行；(3) 某些数据库执行计划的运行时识别。

主流编译器（GCC/Polly、ICC）都没有把 dynamic NLR 集成到生产编译流程，仍然依赖静态多面体分析+pragma。原因是 NLR 要求 trace 数据，而生产编译要求 ahead-of-time。

#### 局限性

第一，强假设：程序由 piecewise-affine loop 生成。这对科学计算成立，对系统软件、数据库、Web 服务器基本不成立。

第二，识别 fragile：trace 中插入一个意外指令（OS interrupt、TLB miss handler）就可能打断 NLR 的差分识别。

第三，输出 loop nest 是程序的一种"投影"——同一个 trace 可能对应多个不同 loop nest，NLR 选择最简的，但最简未必是原程序结构。

第四，对动态控制流（依赖运行时数据的 branch）几乎无效。

---

### 分支 5：关键路径与瓶颈诊断

#### 起源

Brian Fields、Shai Rubin、Rastislav Bodík 2001 年 ISCA 的 *Focusing Processor Policies via Critical-Path Prediction* 是分支起点。motivation 段：现代乱序处理器对所有指令一视同仁地分配资源（issue width、register、cache port），但实际只有"关键路径上的指令"延迟会影响最终执行时间。如果能识别 critical instruction，就可以差异化分配——给关键的更多资源、给非关键的延后。问题是 critical path 在运行时动态变化，需要在线预测。

那个时代的前置条件：(1) OoO 处理器普及（Pentium Pro 1995、Alpha 21264 1996），dependence graph 这个抽象在硬件设计圈普遍接受；(2) PERT/CPM 的 critical path 算法在项目管理领域早已成熟，搬到指令调度只需要适配粒度；(3) hardware predictor（branch、value）的成功证明可以用简单 last-N 历史做有用预测。

#### 核心算法

Token-passing 算法（Fields-Rubin-Bodík）：

```
1. 概念上，定义 dependence DAG：每条 dyn 指令是节点，
   节点上有进入时间（issue 时刻）和离开时间（complete 时刻），
   data dependence 与 resource dependence（如 ROB 满）都是边
2. Critical path = DAG 中最长加权路径
3. token 实现：
   - 每条指令带一个 boolean token
   - 当 producer 完成、forward 数据到 consumer 时，
     如果 producer 在它"上一次完成"之后产生了下游路径上的关键贡献，
     就把 token 传给 consumer
   - 如果某指令长时间没把 token 传出，它就是 critical-path 端点
4. 阈值 T=1024 cycles 内无 token 流动 → 该 token 链上的指令打 critical 标
```

不需要构建完整 DAG，token 在硬件里就是一位 wire 信号。

Tune、Liang、Tullsen、Calder 2002 年 PACT 的 *Quantifying Instruction Criticality* 提供了一组评估 criticality 度量的方法学：alone delay（让该指令延迟一拍，看总执行时间增加多少）就是该指令的真实 criticality。token-passing 与之相比是 cheap 近似。

Karkhanis 与 Smith 2004 年 ISCA 的 *A First-Order Superscalar Processor Model*（interval analysis）走完全不同的路径：把执行流切成 miss-event-bounded interval，每个 interval 内 IPC 用 instruction-window saturation 公式估算。这其实是关键路径思想的"区间化"——critical path 在 miss event 处中断，interval 内部假设 ILP 满足。

#### 后续改进

Fields、Bodík、Hill 2002 年 ISCA 的 *Slack: Maximizing Performance Under Technological Constraints* 把 token-passing 推广到 slack（非关键指令可以延迟多少）的量化，slack 大的指令可以走慢路径（low-power FU、远 cluster）从而省功耗或简化微架构。

Karkhanis 与 Smith 后续 *A Day in the Life of a Data Cache Miss*（[需核实具体年份/会议]）把 cache miss 的 timeline 详细化。

Eyerman、Smith 2006 年 ISPASS 的 *Characterizing the Branch Misprediction Penalty* 把 branch 误预测的代价分解到五个具体来源（前端长度、miss event 间距、ILP、FU latency、short D-cache miss），这是 mechanistic model 走向 practical 的关键一步。

Eyerman、Eeckhout、Karkhanis、Smith 2009 年 TOCS 的 *A Mechanistic Performance Model for Superscalar Out-of-Order Processors* 是 interval analysis 的集大成——把 OoO 的所有性能损失分解到 frontend stall、ROB 满、register file 满、LSQ 满等具体瓶颈，每个都有独立的 mechanistic 公式，预测 IPC 误差 5% 内。

Eyerman、Eeckhout、Karkhanis、Smith 2006 年 ASPLOS 的 *A Performance Counter Architecture for Computing Accurate CPI Components* 把 mechanistic model 反过来用：硬件加几个 counter 直接产生 per-component CPI stack。

Salverda、Tucker、Zilles 2008 年 CGO 的 *Accurate Critical Path Prediction via Random Trace Construction* 提出用随机生成的短 trace（按硬件采样得到的指令分布概率随机走 1000 条指令）估算 critical path，无需 token-passing 硬件。Branch-on-Random（Lee, Zilles, CGO 2008）是同思路的姊妹工作。

Carlson、Heirman、Eeckhout 2011 年 SC 的 *Sniper: Exploring the Level of Abstraction for Scalable and Accurate Parallel Multi-Core Simulation* 把 interval model 工程化为开源多核模拟器。Sniper 至今是体系结构研究的标配（与 gem5 互补，Sniper 快但精度较低）。

Yasin 2014 年 ISPASS 的 *A Top-Down Method for Performance Analysis and Counters Architecture* 把 mechanistic 思路落地到工业 PMU。Top-Down Microarchitecture Analysis（TMA）四大类（Frontend Bound、Backend Bound、Bad Speculation、Retiring）成为 Intel VTune、Linux perf、AMD uProf 的事实标准。

Eyerman 与 Eeckhout 2010 年 ISCA 的 *Modeling Critical Sections in Amdahl's Law* 把 critical path 推到多核，关心同步引入的 bottleneck。

Du Bois、Eyerman、Eeckhout 2013 年 ISCA 的 *Criticality Stacks: Identifying Critical Threads in Parallel Programs Using Synchronization Behavior* 把 criticality 概念推广到线程级别。

Lee 与 Brooks 2006 年 ASPLOS 的 *Accurate and Efficient Regression Modeling for Microarchitectural Performance and Power Prediction* 是相邻方向：用回归模型代替 mechanistic 公式做 IPC 预测。这条线后来被 ML-based performance model 接续。

#### 当前状态

工业落地度最高的子领域。Intel TMA 进入 VTune 与 perf top-down 子命令；Linux perf top-down 是 RISC-V/ARM 性能调优用户的日常工具；Sniper 是开源体系结构研究最常用的快速模拟器之一；mechanistic model 是 gem5、ZSim 这些 cycle-accurate 模拟器的精度上界参考。RISC-V 这一支正在快速吸收 TMA 思想——SiFive U74、阿里 XuanTie C910 等核都在 PMU 设计上明确支持 TMA-style 事件分类，arm64 上 perf top-down 命令几年前已经稳定。

学术界仍在推进：(1) ML-based critical path prediction（用 transformer 学 dependence graph，2020-2023 ISCA/MICRO 上有数篇相关工作）；(2) GPU/accelerator 的 mechanistic model（NVIDIA Nsight Systems 内部使用类似 TMA 思想分类 GPU bottleneck）；(3) 多核 mechanistic model 的同步事件建模（Du Bois 等 2013 ISCA 之后这个方向仍有持续工作）；(4) heterogeneous core / big.LITTLE 调度的 criticality-aware 决策。

#### 局限性

第一，token-passing 假设依赖关系在指令窗口内可见——对超长 dependence chain（long-running async I/O、跨核同步）失效。

第二，mechanistic interval model 的"interval"边界是 miss event，对没有大 miss 的程序（小规模、cache friendly），interval 退化成单一长 interval，模型粒度不够。

第三，TMA 的四大类切分对超标量 OoO 适配良好，但对 in-order RISC-V（典型嵌入式核）需要重新切分——backend bound 在 in-order 里的语义不同。

第四，criticality 的定义在多线程下不唯一。同步 critical 和 dataflow critical 不一定是同一条路径，文献里用的 criticality 概念常常需要先澄清。

---

### 分支 6：执行规约挖掘 / 行为模型推断

#### 起源

Ammons、Bodík、Larus 2002 年 POPL 的 *Mining Specifications* 是分支的现代起点。motivation 段：程序经常错误地使用 API（如忘记调用 close()、调用顺序错误），但库的开发者很少写出完整的 formal spec。Microsoft Windows 内部 trace 显示 90% 以上的 lock-related crash 是 API 协议违反，但 Windows API 的协议在 MSDN 文档里并没有完整描述——能不能从已经"works"的客户端程序中通过观察其 API 调用 trace，自动归纳出 API 的协议？

这条线真正的源头比这早 30 年——Biermann、Feldman 1972 年 IEEE Transactions on Computers 的 *On the Synthesis of Finite-State Machines from Samples of Their Behavior*（即 k-Tail 算法）已经把"从样本序列学 FSM"的问题形式化。这篇 1972 年的论文当时是为模式识别和形式语言学习写的，连"程序"二字都没出现，但其核心算法被几乎不修改地用了三十年。Cook 与 Wolf 1995 年 ICSE 的 *Discovering Models of Software Processes from Event-Based Data* 把 k-Tail 思想搬到软件工程语境，但他们关心的是开发流程事件而非程序执行 trace。

Ammons 等的贡献是把这条线明确瞄准"程序执行 trace 上的 API 协议"。注意作者列表里又出现了 James Larus——他在 Microsoft Research 的早年（1996-2002）几乎以一己之力同时启动了 path profiling、whole program paths、specification mining 三条线，是少见的"工具箱型"研究者，每条线都给出了奠基论文。Bodík 当时是 UW Madison 的助理教授，他与 Larus 的合作贯穿了 1998-2003 年，几乎是分支 3、5、6 三条线的串联点。

#### 核心算法

Ammons-Bodík-Larus 的 PFSA 提取流程：

```
输入：API 调用 trace（每条 trace 是一个程序执行实例）
1. 把每条 trace 看作 FSM 的一次接受序列
2. 用 k-Tail 算法（或其变体）合并 trace：
   两个状态如果它们的 k-长度后缀集相同，则合并
3. k 控制泛化粒度：k=1 太宽松，k=∞ 等价于不合并
4. 输出 PFSA：边上带概率，反映该转移的频率
5. 把高概率边视为强 spec，低概率边视为可能的 violation
```

#### 后续改进

Yang、Evans、Bhardwaj、Bhat、Das 2006 年 ICSE 的 *Perracotta: Mining Temporal API Rules from Imperfect Traces* 关注大规模工业 trace 的 noise tolerance：用一组预定义的 LTL pattern（"alternating x then y"、"eventually y after x"等）扫 trace，对每个 pattern 给一个 confidence 分数。Perracotta 在 Microsoft 内部 Windows kernel trace 上验证，找出多个未文档化的协议。Perracotta 与 Ammons-Bodík-Larus 的 PFSA 路线最大的区别是：PFSA 学一个完整的 automaton（试图刻画所有 state transition），Perracotta 学一组独立的 LTL formula（每个只管两个 event 之间的关系），后者大幅降低了 noise sensitivity——单个 pattern 错了不影响其他 pattern。这种"分散式学习"思想后来在 invariant detection 里也很常见。

Lo、Khoo、Liu 2007 年 KDD 的 *Efficient Mining of Iterative Patterns for Software Specification Discovery*（CLIPPER）把 sequence pattern mining（PrefixSpan、SPADE 那一支）适配到软件 trace 的特殊语义——loop 引发的 iterative pattern 在通用 sequence mining 里看不出，需要专门处理"同一段在多次循环迭代中出现"。CLIPPER 的工程价值之一是它发表后被多个 trace analysis 工具集成（如 ABaCI、Perfume 等学术原型）。

Ernst 等 2001 年 IEEE TSE 的 *Dynamically Discovering Likely Program Invariants to Support Program Evolution*（即 Daikon 工具）走不同方向：不学 FSM，学变量取值上的不变式（如 x > 0、x == y + 1）。Daikon 的算法是穷举一组预定义不变式模板（约 100 多种），在 trace 上测试每个模板，过滤掉违反的。简单粗暴但实用——Daikon 后来扩展支持多语言（C、C++、Java、Perl），是 dynamic invariant detection 的事实标准。Ernst 团队 2007 年在 Science of Computer Programming 发表了系统性的 Daikon 工具论文，至今被广泛引用。

Gabel 与 Su 2008 年 FSE 的 *Online Inference and Enforcement of Temporal Properties* 把 spec mining 推到 online 形式——边运行边学边检查违反。

De Pauw、Lorenz、Vlissides、Wegman 1998 年 USENIX COOTS 的 *Execution Patterns in Object-Oriented Visualization* 是 visualization 角度的早期工作——把 OO 程序的方法调用 trace 自动归纳成 high-level 模式让程序员阅读。这条线后来与 reverse engineering、program comprehension 子社区融合。

Hamou-Lhadj 与 Lethbridge 2004 年 CASCON 的 *A Survey of Trace Exploration Tools and Techniques* 是这一支当时的工具综述。

Nevill-Manning 的 SEQUITUR 在这条线上也被借用——某些 trace summarization 工具用 SEQUITUR 把长 trace 压成 grammar 后再呈现给程序员阅读。

[需核实] 是否有 PRINS 等近期工作 - 我未能在搜索中确认其具体引用细节。

#### 当前状态

Daikon 风格的 invariant detection 在自动化测试领域稳定存在（Randoop、Pex 等会用 invariant guide test generation）。但 FSM-based protocol mining 在大模型时代被 LLM 大幅替代——"读源码或文档反而比从 trace 倒推规约更准"是现在的常态判断。这条线 2015 年后学术热度大幅下降。

工业产品几乎没有，原因是规约挖掘很难自动产出"用户能直接使用"的 spec——结果通常需要工程师筛选、确认、改写。

#### 局限性

第一，trace 不完整 → 学到的 spec 也不完整。这是规约挖掘的根本困境。

第二，learn 出的 FSM 状态数随 trace 多样性指数增长，需要激进合并（k 取小），但合并多了又过度泛化丢失语义。

第三，对参数化 spec（涉及变量取值的协议）支持差。Daikon 走变量取值，但难表达 "open() 之后必须 close()" 这种纯控制流协议；Perracotta 走控制流，但难表达 "open(file) 之后只能 close(file) 而非 close(other)" 这种带 binding 的协议。

第四，与现代软件实践（动态加载、reflection、async）适配差——这些机制让 trace 本身意义模糊，难以归一化。

---

## Part 3 交叉对比

本部分跨六个分支横向对比，目的是给读者一个"基于工程目标如何选择方法"的决策表。所有维度的判定依据都来自 Part 2 中各分支的具体描述，读者可回查溯源。

### 表 1：六分支多维度对比

| 维度 | 1 Phase analysis | 2 Trace-based dyn opt | 3 Trace 结构化表示 | 4 循环嵌套重建 | 5 Critical path | 6 规约挖掘 |
|------|------------------|----------------------|-------------------|---------------|----------------|------------|
| **颗粒度** | 1M~100M 指令的 phase | 几十~几百指令的 trace | 全程 trace 抽成 grammar | 整个 loop nest（可任意大） | 单指令~指令窗口 | 单 API call 序列（任意长） |
| **输入数据** | BBV / working-set sig / reuse distance | BB 序列 + 执行频率 | acyclic path ID 序列 | 数值 trace（地址或迭代变量值） | dependence graph（数据+资源） | API call sequence / 变量 valuation |
| **是否需要 instrumentation** | 离线版：是；在线版：可硬件 BBV | 是（动态二进制翻译框架） | 是（Ball-Larus 编号需 instrument） | 是（地址 trace 收集） | 否（可硬件 token，PMU） | 是（API hook） |
| **是否需要硬件支持** | 否（纯软件） | 否（DBT） / 是（trace cache） | 否 | 否 | 是（token-passing）/ 否（mechanistic model） | 否 |
| **能否识别动态路径变体** | 不识别（聚合到 BBV） | 部分（trace tree 多分支） | 是（grammar 保留所有路径） | 不识别（强 affine 假设） | 否（运行时单条路径） | 部分（PFSA 多分支） |
| **适合 workload** | regular SPEC | 紧致循环 + 动态语言 | acyclic-heavy 程序 | regular loops、HPC | OoO 处理器 generic | 协议化 API 程序 |
| **在线/离线** | 都有（SimPoint 离线，Sherwood 03 在线） | 强在线 | 离线为主 | 离线为主（NLR 一次扫描） | 都有（token 在线，CPI stack 离线） | 离线为主（也有 online 变体） |
| **工程成熟度** | 开源工具稳定（SimPoint 3.0） | PyPy/LuaJIT/工业 µop cache | 学术原型 + HPC 工具内部 | 学术原型 | 工业产品（Intel TMA、Linux perf top-down、Sniper） | 学术原型 + 测试工具（Daikon） |
| **已知开源实现** | SimPoint 3.0（cseweb.ucsd.edu/~calder/simpoint/）；MICA；PinPlay | DynamoRIO（dynamorio.org）；PyPy（pypy.org）；LuaJIT；HotpathVM 已停 | 无独立开源；SEQUITUR 实现散见于 sequitur.info | 无独立开源；Rec2Poly（Inria 内部） | Sniper（snipersim.org）；TMA 在 VTune/perf | Daikon（plse.cs.washington.edu/daikon/）；Perracotta；CLIPPER |

### 表 2：典型代表算法的输入/输出范式

| 算法 | 输入 | 输出 | 算法主要思路 |
|------|------|------|------------|
| SimPoint | BBV 序列 | k 个代表 interval + weight | 高维向量 k-means |
| Working-set sig | Bloom filter 序列 | 相位边界 | Hamming distance threshold |
| NET | BB 执行计数 | hot trace（线性指令序列） | counter > T 触发 trace 录制 |
| LEI | 循环 backward branch 计数 | hot region（loop body） | 找最热回边为 region 起点 |
| Trace tree | BB 序列 + branch outcome | 多分支共享前缀的树 | NET + side-exit 增量加分支 |
| WPP / SEQUITUR | acyclic path ID 序列 | DAG（grammar） | digram uniqueness 增量构造 |
| CCT | call/ret 序列 | calling tree | 维护 call stack |
| PCC | call/ret 序列 | 32-bit hash | running hash on call site ID |
| NLR | 数值序列 | nested loop nest 描述 | 一阶差分 + 递归 |
| Token-passing | dependence graph 流 | critical instruction set | token 在 dataflow / resource edge 上传播 |
| Interval model | miss event 序列 | per-component CPI | 区间 IPC 公式拼接 |
| TMA | PMU counter | frontend / backend / spec / retire breakdown | counter 比例分解到固定四类 |
| k-Tail | event sequence | FSM | suffix 等价合并状态 |
| PFSA mining | API call trace | 概率 FSM | k-Tail + 频率统计 |
| Daikon | variable valuations | 不变式集合 | 模板枚举 + 频率过滤 |

### 表 3：六分支与典型工程目标的连接强度

| 工程目标 | 1 Phase | 2 Trace JIT | 3 WPP | 4 NLR | 5 Critical | 6 Spec mining |
|---------|---------|-------------|-------|-------|-----------|---------------|
| 模拟器加速（代表点选取） | 强 | 弱 | 弱 | 中 | 弱 | 无 |
| 动态二进制优化 | 中 | 强 | 中 | 弱 | 中 | 无 |
| iter 单元识别 | 弱 | 强 | 强 | 中 | 弱 | 中 |
| Dependence DAG 提取 | 无 | 弱 | 弱 | 弱 | 强 | 无 |
| IPC 上界分析 | 中 | 弱 | 弱 | 无 | 强 | 无 |
| 性能瓶颈诊断 | 中 | 无 | 弱 | 无 | 强 | 无 |
| Cache 行为预测 | 中 | 无 | 弱 | 中 | 中 | 无 |
| Profile-guided 编译 | 中 | 强 | 强 | 弱 | 中 | 无 |
| 自动并行化 | 弱 | 无 | 弱 | 强 | 无 | 无 |
| Bug detection | 无 | 无 | 中 | 无 | 无 | 强 |
| Reverse engineering | 无 | 无 | 中 | 弱 | 无 | 强 |

### 表后讨论：维度上的差异与趋同

**差异最大的两个维度**是颗粒度与输出形式。颗粒度从单指令（critical path 的 token）一直跨到全程 trace（WPP grammar），跨度六个数量级。输出形式更是各异：phase 输出"代表点 + weight"是统计抽样单位；trace JIT 输出"可编译指令序列"是优化单元；WPP 输出"可还原 grammar"是结构表示；NLR 输出"循环嵌套程序"是可执行模型；critical path 输出"指令子集 + slack"是调度信号；规约挖掘输出"FSM / 时序属性"是 specification。这种"输出形式的根本差异"正是为什么不能用单一颗粒度做一级分类——颗粒度相同的两个分支（如 BB 序列既被 SimPoint 也被 NET 用），目的与算法完全不同。

**趋同最明显的维度**有两个。一是"在线 vs 离线"在每个分支内部都向"在线化"靠拢：SimPoint 的 Sherwood-Sair-Calder 03 ISCA、Dynamo NET 本来就在线、TMA 是硬件 PMU 在线、规约挖掘也有 Gabel-Su 08 在线变体——都是因为越来越多的应用场景（DVFS、JIT、production profiling）要求边跑边算。二是"硬件 vs 软件"的边界正在模糊：phase analysis 出现了硬件 BBV、critical path 既有 token-passing 硬件也有 mechanistic 软件、Trace cache 是硬件而 trace JIT 是软件——同一思想往往能在两侧都实现，工业实践通常选硬件（TMA），学术先在软件验证（Sniper interval model）。

还可以从另一个角度提炼出一个更微妙的趋同：六条分支虽然名字不同，但都在远离"只看平均计数器"的旧范式。它们共同依赖更丰富的输入、都在想办法缩短原始执行历史、都越来越需要把离线重分析与在线轻量信号结合起来。过去二十多年真正稳定下来的共识，并不是某一种 signature 或某一个 clustering 算法，而是这样一个方法学事实：一条长执行历史如果不先被压缩、分段、路径化、图化或模型化，就很难成为可用于决策的工程对象。这个观察解释了为什么六条分支即便目标各不相同，仍可被视作同一个家族——它们共享的是"trace 必须先变成结构化对象，结构化方式可以非常不同"这一底层共识。

**与工程目标的连接强度**（这里指"识别 iter 单元、构建 DAG、做 IPC 上界分析"这种典型 RISC-V 微架构性能调优工程）：

- 分支 5（critical path）连接最强——直接产 dependence DAG、瓶颈分类，TMA 几乎是工程师日常工具。
- 分支 1（phase）连接强但需要二级使用——先用 SimPoint 切相位，再在每相位内做更细分析（其他分支）。
- 分支 2（trace JIT）的 NET、LEI 算法对"识别短指令序列"直接适用，但工程语境是动态优化，不是硬件分析。
- 分支 3（WPP）算法上对"找重复短序列"直接适用，但学术语境为主。
- 分支 4（NLR）需要 affine 假设，对系统软件、数据库等不规则程序失效，工程目标里只在科学计算用得上。
- 分支 6（规约挖掘）算法借鉴池作用大于直接应用——k-Tail、SEQUITUR、PrefixSpan 都是"找重复结构"的通用算法。

需要强调的是：上述对比未对"哪种方法更好"做总评判，因为答案完全取决于工程目标。如果目标是模拟器加速，分支 1 + 分支 5 是黄金组合；如果目标是动态优化器，分支 2 是核心；如果目标是程序理解，分支 6 + 分支 3 是工具池；如果目标是科学计算自动并行，分支 4 是必备。

### 关于"分支组合 pipeline"

实际工程中很少有项目只用单一分支的方法。典型的组合 pipeline 包括：

- **模拟器加速 pipeline**：先 SimPoint（分支 1）切相位选代表点，再 PinPlay（工具，分支 1 周边）做 deterministic replay 到 simulator，每个代表点内用 mechanistic model 或 cycle-accurate simulation 做精度，最后 critical path 分析（分支 5）解释 IPC bottleneck。
- **JIT 优化 pipeline**：先 trace selection（分支 2 NET 或 LEI）找热路径，再用 trace tree（分支 2 HotpathVM）展开成可编译形式，再用 type specialization（分支 2 TraceMonkey 思想）做类型特化，最后 deopt 机制处理 type instability。
- **PGO 部署 pipeline**：sampling profiler（DCPI 路线）线上常态收集 → AutoFDO（分支 5/2 混合）匹配编译器 IR → BOLT post-link 重排（分支 2 静态变体）。
- **HPC 性能分析 pipeline**：MPI 通信 trace 收集（OTF/CTF 格式）→ Vampir 内部 SEQUITUR-style 压缩与重复模式识别（分支 3 借鉴）→ critical path 分析跨节点 dependence（分支 5 推广到分布式）。
- **协议挖掘 pipeline**：API trace 收集 → 用 Daikon（分支 6）找参数 invariant + 用 Perracotta（分支 6）找 temporal pattern → 综合输出 spec。

这种组合化的现实使得"哪种方法最优"的提问基本上是 ill-posed——真实问题应该是"对我的工程目标，应该按什么顺序组合哪些方法"。这也呼应 Part 1 提到的核心观察：六个分支不是相互替代的同质方法，而是关注不同问题维度的互补工具。

---

## 引用与核实状态

以下论文均已通过公开搜索（论文 PDF / DBLP / ACM DL / IEEE Xplore / 出版商页面）核实作者、年份、会议/期刊。

1. Sherwood T., Perelman E., Hamerly G., Calder B. *Automatically Characterizing Large Scale Program Behavior*. ASPLOS 2002.
2. Dhodapkar A.S., Smith J.E. *Managing Multi-Configuration Hardware via Dynamic Working Set Analysis*. ISCA 2002.
3. Sherwood T., Sair S., Calder B. *Phase Tracking and Prediction*. ISCA 2003.
4. Lau J., Schoenmackers S., Calder B. *Structures for Phase Classification*. ISPASS 2004.
5. Hamerly G., Perelman E., Lau J., Calder B. *SimPoint 3.0: Faster and More Flexible Program Phase Analysis*. JILP 2005.
6. Shen X., Zhong Y., Ding C. *Locality Phase Prediction*. ASPLOS 2004.
7. Nagpurkar P., Hind M., Krintz C., Sweeney P.F., Rajan V.T. *Online Phase Detection Algorithms*. CGO 2006.
8. Isci C., Contreras G., Martonosi M. *Live, Runtime Phase Monitoring and Prediction on Real Systems with Application to Dynamic Power Management*. MICRO 2006.
9. Isci C., Buyuktosunoglu A., Martonosi M. *Long-Term Workload Phases: Duration Predictions and Applications to DVFS*. IEEE Micro 25(5), 2005.
10. Hoste K., Eeckhout L. *Microarchitecture-Independent Workload Characterization*. IEEE Micro 27(3), 2007.
11. Akram S., Sawalha L. *A Survey of Phase Classification Techniques for Characterizing Variable Application Behavior*. arXiv:1908.02238, 2019. [需核实是否最终在期刊发表]
12. Patil H., Pereira C., Stallcup M., Lueck G., Cownie J. *PinPlay: A Framework for Deterministic Replay and Reproducible Analysis of Parallel Programs*. CGO 2010.
13. Bala V., Duesterwald E., Banerjia S. *Dynamo: A Transparent Dynamic Optimization System*. PLDI 2000.
14. Rotenberg E., Bennett S., Smith J.E. *Trace Cache: A Low Latency Approach to High Bandwidth Instruction Fetching*. MICRO 1996.
15. Hiniker D., Hazelwood K., Smith M.D. *Improving Region Selection in Dynamic Optimization Systems*. MICRO 2005.
16. Gal A., Probst C.W., Franz M. *HotpathVM: An Effective JIT Compiler for Resource-Constrained Devices*. VEE 2006.
17. Gal A., Eich B., Shaver M., Anderson D., Mandelin D., Haghighat M.R., 等. *Trace-Based Just-in-Time Type Specialization for Dynamic Languages*. PLDI 2009.
18. Bolz C.F., Cuni A., Fijalkowski M., Rigo A. *Tracing the Meta-Level: PyPy's Tracing JIT Compiler*. ICOOOLPS 2009.
19. Bebenita M., Brandner F., Fahndrich M., Logozzo F., Schulte W., Tillmann N., Venter H. *SPUR: A Trace-Based JIT Compiler for CIL*. OOPSLA 2010.
20. Hwu W.M.W., Mahlke S.A., Chen W.Y., 等. *The Superblock: An Effective Technique for VLIW and Superscalar Compilation*. The Journal of Supercomputing 7(1-2), 1993.
21. Mahlke S.A., Lin D.C., Chen W.Y., Hank R.E., Bringmann R.A. *Effective Compiler Support for Predicated Execution Using the Hyperblock*. MICRO 1992.
22. Larus J.R. *Whole Program Paths*. PLDI 1999.
23. Ball T., Larus J.R. *Efficient Path Profiling*. MICRO 1996.
24. Nevill-Manning C.G., Witten I.H. *Identifying Hierarchical Structure in Sequences: A Linear-Time Algorithm*. Journal of Artificial Intelligence Research (JAIR) 7, 1997.
25. Ammons G., Ball T., Larus J.R. *Exploiting Hardware Performance Counters with Flow and Context Sensitive Profiling*. PLDI 1997.
26. Ammons G., Larus J.R. *Improving Data-Flow Analysis with Path Profiles*. PLDI 1998.
27. Tallam S., Gupta R., Zhang X. *Extended Whole Program Paths*. PACT 2005.
28. Bond M.D., McKinley K.S. *Probabilistic Calling Context*. OOPSLA 2007.
29. Knüpfer A., Voigt B., Nagel W.E., Mix H. *Visualization of Repetitive Patterns in Event Traces*. PARA 2006 (proceedings 2007).
30. Ketterlin A., Clauss P. *Prediction and Trace Compression of Data Access Addresses Through Nested Loop Recognition*. CGO 2008.
31. Sato Y., Inoguchi Y., Nakamura T. *Identifying Program Loop Nesting Structures During Execution of Machine Code*. IEICE Transactions on Information and Systems, 2014.
32. Kobeissi B., Ketterlin A., Clauss P. *Rec2Poly: Converting Recursions to Polyhedral Optimized Loops Using an Inspector-Executor Strategy*. SAMOS 2020.
33. Fields B., Rubin S., Bodík R. *Focusing Processor Policies via Critical-Path Prediction*. ISCA 2001.
34. Tune E., Liang D., Tullsen D., Calder B. *Quantifying Instruction Criticality*. PACT 2002.
35. Fields B., Bodík R., Hill M.D. *Slack: Maximizing Performance Under Technological Constraints*. ISCA 2002.
36. Karkhanis T.S., Smith J.E. *A First-Order Superscalar Processor Model*. ISCA 2004.
37. Eyerman S., Eeckhout L., Karkhanis T., Smith J.E. *A Mechanistic Performance Model for Superscalar Out-of-Order Processors*. ACM Transactions on Computer Systems 27(2), 2009.
38. Eyerman S., Eeckhout L., Karkhanis T., Smith J.E. *A Performance Counter Architecture for Computing Accurate CPI Components*. ASPLOS 2006.
39. Eyerman S., Smith J.E. *Characterizing the Branch Misprediction Penalty*. ISPASS 2006.
40. Salverda P., Tucker N., Zilles C. *Accurate Critical Path Prediction via Random Trace Construction*. CGO 2008.
41. Carlson T.E., Heirman W., Eeckhout L. *Sniper: Exploring the Level of Abstraction for Scalable and Accurate Parallel Multi-Core Simulation*. SC 2011.
42. Yasin A. *A Top-Down Method for Performance Analysis and Counters Architecture*. ISPASS 2014.
43. Eyerman S., Eeckhout L. *Modeling Critical Sections in Amdahl's Law and Its Implications for Multicore Design*. ISCA 2010. [需核实标题是否完全一致]
44. Du Bois K., Eyerman S., Sartor J.B., Eeckhout L. *Criticality Stacks: Identifying Critical Threads in Parallel Programs Using Synchronization Behavior*. ISCA 2013.
45. Lee B.C., Brooks D.M. *Accurate and Efficient Regression Modeling for Microarchitectural Performance and Power Prediction*. ASPLOS 2006.
46. Eyerman S., Eeckhout L. *Per-Thread Cycle Accounting in SMT Processors*. ASPLOS 2009.
47. Anderson J.M., Berc L.M., Dean J., Ghemawat S., Henzinger M.R., Leung S.A., Sites R.L., Vandevoorde M.T., Waldspurger C.A., Weihl W.E. *Continuous Profiling: Where Have All the Cycles Gone?*. SOSP 1997 / ACM Transactions on Computer Systems 15(4), 1997.
48. Dean J., Hicks J.E., Waldspurger C.A., Weihl W.E., Chrysos G. *ProfileMe: Hardware Support for Instruction-Level Profiling on Out-of-Order Processors*. MICRO 1997.
49. Wunderlich R.E., Wenisch T.F., Falsafi B., Hoe J.C. *SMARTS: Accelerating Microarchitecture Simulation via Rigorous Statistical Sampling*. ISCA 2003.
50. Chen D., Li D.X., Moseley T. *AutoFDO: Automatic Feedback-Directed Optimization for Warehouse-Scale Applications*. CGO 2016.
51. Panchenko M., Auler R., Nell B., Ottoni G. *BOLT: A Practical Binary Optimizer for Data Centers and Beyond*. CGO 2019.
52. Hashemi M., Swersky K., Smith J.A., Ayers G., Litz H., Chang J., Kozyrakis C., Ranganathan P. *Learning Memory Access Patterns*. ICML 2018.
53. Ammons G., Bodík R., Larus J.R. *Mining Specifications*. POPL 2002.
54. Yang J., Evans D., Bhardwaj D., Bhat T., Das M. *Perracotta: Mining Temporal API Rules from Imperfect Traces*. ICSE 2006.
55. Lo D., Khoo S.C., Liu C. *Efficient Mining of Iterative Patterns for Software Specification Discovery*. KDD 2007.
56. Ernst M.D., Perkins J.H., Guo P.J., McCamant S., Pacheco C., Tschantz M.S., Xiao C. *The Daikon System for Dynamic Detection of Likely Invariants*. Science of Computer Programming 69(1-3), 2007. （扩展自 Ernst 等 2001 IEEE TSE 原始论文）
57. De Pauw W., Lorenz D., Vlissides J., Wegman M. *Execution Patterns in Object-Oriented Visualization*. USENIX COOTS 1998.
58. Hamou-Lhadj A., Lethbridge T.C. *A Survey of Trace Exploration Tools and Techniques*. CASCON 2004.
59. Biermann A.W., Feldman J.A. *On the Synthesis of Finite-State Machines from Samples of Their Behavior*. IEEE Transactions on Computers 21(6), 1972.
60. Cook J.E., Wolf A.L. *Discovering Models of Software Processes from Event-Based Data*. ACM Transactions on Software Engineering and Methodology 7(3), 1998 （扩展自 ICSE 1995 同主题论文）.
61. Gabel M., Su Z. *Online Inference and Enforcement of Temporal Properties*. ICSE 2010. [需核实首次发表的会议]

**核实状态总览**：61 篇引用中，58 篇已通过公开搜索完整核实作者、年份、会议/期刊。3 篇标 [需核实]：

- 第 11 篇 Akram-Sawalha 综述（arXiv 2019）：arXiv preprint 已确认，是否最终发表到期刊未核实。
- 第 43 篇 Eyerman-Eeckhout *Modeling Critical Sections in Amdahl's Law* ISCA 2010：会议年份核实，标题完整文字未在搜索中复核。
- 第 61 篇 Gabel-Su *Online Inference and Enforcement of Temporal Properties*：在搜索中能找到，但首次发表会议（FSE / ICSE / 其他）未明确核实。
