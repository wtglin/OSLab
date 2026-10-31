# 功能模块二：物理内存分配功能
## 任务二：Best-Fit 连续物理页分配器
[PROMPT]

**任务**：请为当前 ucore Lab2 工程实现并接入 Best-Fit（最佳适应）连续物理页分配器。当前工作目录下的工程根目录为 `lab2/lab2_new/`，以下源码路径均相对于该工程根目录。

在 `kern/mm/best_fit_pmm.c` 的 `//lab2 function2-2 YOUR CODE` 标记之后，补全管理器内部状态、管理函数以及 `best_fit_pmm_manager` 注册对象。
在 `kern/mm/pmm.c` 的 `init_pmm_manager()` 中，将当前管理器从 `default_pmm_manager` 切换为 `best_fit_pmm_manager`。
本任务完成的是物理页分配：从空闲块中选择最小的合适块，精确分配所请求的连续页数，正确分割、释放和合并，使初始化、分配、回收、计数和检查形成完整模块。

**操作要求**：

1. 执行此提示词时，必须修改工程中的实际文件，而不是只在回复中展示代码。先阅读 `kern/mm/default_pmm.c`、`kern/mm/best_fit_pmm.c`、`kern/mm/best_fit_pmm.h`、`kern/mm/pmm.h`、`kern/mm/pmm.c`、`kern/mm/memlayout.h`、`libs/list.h` 和 `libs/defs.h`，核对接口与现有测试。
2. 只允许修改上述两个目标 `.c` 文件。`best_fit_pmm.c` 仅在指定标记处增加实现，保留已有头文件包含、注释及两个测试函数；`pmm.c` 仅修改 `init_pmm_manager()` 中选择管理器的赋值语句，保留其他逻辑。
3. 不得修改 `basic_check()`、`best_fit_check()`、评分脚本、现有公开头文件、`struct Page` 或 `struct pmm_manager`；不得通过跳过检查、伪造输出或改写断言使测试通过。
4. 参考 First-Fit 的状态维护方式，但分配时必须遵守 Best-Fit 选择规则，不能仅改名称后仍选择第一个合适块。不引入 Buddy、SLUB、动态页表映射或其他任务。
5. 当前任务依赖功能模块一已经正确建立物理页描述符和初始空闲区。若实际工程仍缺少 `page_init()`，完成本任务范围内的实现与接入后，应保留该依赖现状并说明验证受阻，不得擅自补写或绕过它。

**输出要求**：

使用下述 `[RELY]`、`[GUARANTEE]` 和 `[SPECIFICATION]` 实现；接口定义以实际工程为准。发现不能兼容的约束时先说明具体冲突，不得静默改动禁止修改的部分。
完成后说明修改文件、各接口职责、Best-Fit 与 First-Fit 的关键差别，以及分割和双向合并如何维持页数守恒。
用简短例子解释 `Page`、空闲块、`page_link` 与页表项的区别，说明 `le2page()` 为什么能从成员地址找回描述符。
在配套工具链与初始化依赖齐备时进行编译、运行和已有检查，可使用工程提供的 `make qemu`、`make grade`。若前置条件不足，列出实际尝试、失败原因和未完成验证项；不能把静态分析写成测试已通过。
输出实际结果摘要，不要求完整运行地址与讲义示例完全相同，不新增无关日志。保留已有的管理器名称和检查输出；不得手工打印成功字符串代替真实检查。
简述当前算法的查找复杂度，以及按大小建立索引等改进方向和相邻块合并的配套代价；本任务不要求实施这些优化。

[RELY]

以下定义只作为已有上下文引用，不要在目标文件中重复定义已有类型或公开接口。

**1. 管理器接口与调用关系**

`kern/mm/pmm.h` 已有以下接口，排版作了压缩，成员类型保持一致：

```c
struct pmm_manager {
    const char *name;
    void (*init)(void);
    void (*init_memmap)(struct Page *base, size_t n);
    struct Page *(*alloc_pages)(size_t n);
    void (*free_pages)(struct Page *base, size_t n);
    size_t (*nr_free_pages)(void);
    void (*check)(void);
};

extern const struct pmm_manager *pmm_manager;
struct Page *alloc_pages(size_t n);
void free_pages(struct Page *base, size_t n);
size_t nr_free_pages(void);

#define alloc_page() alloc_pages(1)
#define free_page(page) free_pages(page, 1)
```

`pmm.c` 中的对外分配、释放、计数接口会转发给当前管理器。`pmm_init()` 依次选择并初始化管理器、调用 `page_init()` 注册空闲页，然后通过 `pmm_manager->check()` 检查当前算法。`best_fit_pmm.h` 已声明：

```c
extern const struct pmm_manager best_fit_pmm_manager;
```

接口注释允许不同算法有不同粒度，但本次 Best-Fit 规定成功时精确取出 `n` 页，不进行幂次取整。

**2. 页描述符、空闲块与状态**

`kern/mm/memlayout.h` 已提供：

```c
struct Page {
    int ref;
    uint64_t flags;
    unsigned int property;
    list_entry_t page_link;
};

typedef struct {
    list_entry_t free_list;
    unsigned int nr_free;
} free_area_t;

#define PG_reserved 0
#define PG_property 1
```

可使用既有的 `PageReserved`、`SetPageReserved`、`ClearPageReserved`、`PageProperty`、`SetPageProperty`、`ClearPageProperty` 宏，以及 `page_ref()`、`set_page_ref()`。
一个 `Page` 只描述一个物理页，不是整个空闲块，也不是硬件页表项。`sizeof(struct Page)` 与物理页大小不是同一个量。
对空闲块头，`property` 表示块内物理页数量，`PG_property` 为 1；内部页不是独立链表节点，不能仅凭其 `PG_property=0` 判断它已分配。
只有空闲块头的 `page_link` 接入空闲链表。`PG_reserved` 表示该页不能交给普通分配器。
`ref` 是软件引用计数，不是 PTE 的访问权限；现有测试要求新分配页的引用计数为 0，不要在本任务中自动加一。

**3. 地址、指针与链表工具**

页大小由 `kern/mm/mmu.h` 的 `PGSIZE=4096`、`PGSHIFT=12` 给出。已有变量和转换关系为：

```c
extern struct Page *pages;
extern size_t npage;
extern const size_t nbase;

// pmm.h 中已有实现：
// page2ppn(p) = p - pages + nbase
// page2pa(p)  = page2ppn(p) << PGSHIFT
// pa2page(pa) = &pages[PPN(pa) - nbase]
```

`pages` 是描述符数组的虚拟地址，`npage` 是物理页号上界，描述符数量为 `npage - nbase`。同一描述符数组内，`p + n` 表示向后移动 `n` 个描述符，对应物理地址向后移动 `n * PGSIZE`，不能把描述符地址当成物理地址。

`libs/list.h` 提供循环双向链表及 `list_init`、`list_add`、`list_add_before`、`list_del`、`list_empty`、`list_next`、`list_prev` 等操作；`list_add(a, b)` 是在节点 `a` 之后插入节点 `b`。链表头是哨兵，不是有效 `Page` 节点，不可对哨兵调用 `le2page()`。

已有宏：

```c
// kern/mm/memlayout.h
#define le2page(le, member) \
    to_struct((le), struct Page, member)

// libs/defs.h
#define to_struct(ptr, type, member) \
    ((type *)((char *)(ptr) - offsetof(type, member)))
```

`le2page(le, page_link)` 通过减去成员偏移，取得包含该链表节点的 `Page *`，不涉及 MMU 或页表查询。本任务不修改 PTE、`satp` 或页访问权限；空闲与已分配状态变化不等于页表权限变化。

**4. 已有测试的状态约定**

`best_fit_pmm.c` 的两个测试直接使用可赋值的 `free_list` 和 `nr_free`，并保存、清空、恢复它们。使用模块私有的 `free_area_t` 并提供同名宏，可与现有约定一致，不与 First-Fit 共享内部状态。
测试会先把链表暂时清空，再把计数暂时归零；这段测试过渡期可能出现“链表为空而计数尚非零”。此时分配必须因找不到块而返回 `NULL`，不能只相信计数，也不能在入口强制断言链表总页数必等于计数。
不要新增依赖测试无法保存、恢复的隐藏空闲索引或分配历史状态，否则恢复链表和计数后可能失配。
测试允许归还一次申请范围中的子区间，也会在各子区间重新分配后，将整段连续已分配页面统一归还。因此释放契约按当前页范围定义，不要求与某次原始申请边界完全一致。
现有框架可使用 `assert()`、`panic()` 和 `cprintf()`，不依赖宿主标准库、`malloc()` 或尚未实现的内核堆分配器。

[GUARANTEE]

**在 `kern/mm/best_fit_pmm.c` 中提供以下主要接口。**内部函数名称采用下列命名，以便说明和核对：

```c
static void best_fit_init(void);
static void best_fit_init_memmap(struct Page *base, size_t n);
static struct Page *best_fit_alloc_pages(size_t n);
static void best_fit_free_pages(struct Page *base, size_t n);
static size_t best_fit_nr_free_pages(void);

// 既有测试函数的前向声明，不重写其函数体：
static void best_fit_check(void);

const struct pmm_manager best_fit_pmm_manager = {
    /* 将 name、init、init_memmap、alloc_pages、free_pages、
       nr_free_pages、check 注册为对应名称和函数。 */
};
```

注册对象的 `.name` 必须为 `"best_fit_pmm_manager"`，`.check` 必须指向已有 `best_fit_check`。注册对象不是 `static`，与头文件已有 `extern` 声明一致。由于新增代码位于测试函数之前，应正确处理函数声明顺序。

**提供与测试兼容的模块内部状态：**

```c
static free_area_t free_area;
#define free_list (free_area.free_list)
#define nr_free (free_area.nr_free)
```

**修改 `kern/mm/pmm.c` 已有函数 `static void init_pmm_manager(void)`：**令 `pmm_manager` 指向 `&best_fit_pmm_manager`，继续使用原有的名称输出和 `pmm_manager->init()` 调用。

允许增加仅在本模块使用的 `static` 辅助函数、必要的内部宏；不增加新的跨文件接口，不额外申请动态管理内存，不重定义既有类型，不改动两个测试函数。

[SPECIFICATION]

## 共同状态约束

下列约束适用于合法调用完成后的正常稳定状态；已有测试主动制造的临时隔离状态按 `[RELY]` 中的特别约定处理，不要求在该过渡状态强行修正计数。
空闲链表按对应物理地址递增排列，节点恰好代表各空闲块的头页，前后链接一致。
各空闲块互不重叠，长度为正；物理相邻且都空闲的块应合并，不能跨保留页或已分配页合并。
空闲块头的 `PG_property` 为 1，`property` 为实际连续页数；空闲块内部页不得带有空闲块头标记。非块头的 `property` 不作为有效块长，不依赖旧值推断状态。
`nr_free` 等于所有空闲块长度之和，统计的是页数而不是块数；正常状态下不超过管理范围。
分配成功扣除 `n` 页，归还合法范围增加 `n` 页；分割和合并本身不额外增减页数。
保留页不进入空闲链表；同一物理页不得被重复分配给两个尚未释放的申请。
本任务不扩展多核锁或并发分配机制。

## best_fit_init

**Pre-Condition**：管理器已被选中，尚未向该管理器登记可用物理页；这是启动初始化，不是在仍有存活分配时重置管理器。

**Post-Condition**：形成合法的空循环双向链表，空闲页数为 0，内部状态可接受后续 `init_memmap()` 调用。

**Requirements**：只初始化本模块状态，不自行探测 RAM、不建立 `pages` 数组、不覆盖其他管理器或页表数据。

## best_fit_init_memmap

**Pre-Condition**：`n > 0`，管理器已初始化；`base` 指向描述符数组中的合法页，`[base, base+n)` 对应同一有效 RAM 区域内的连续物理页，且这些页在交付前均为保留状态、与已登记空闲区不重叠。调用者已经排除固件、内核及描述符数组等占用区。

**Post-Condition**：该范围成为可分配空间，引用计数清零，页面状态符合空闲块约定；其页数计入 `nr_free`，原有空闲范围保持可用。

**Case 1**：原链表为空时，登记这段连续页，形成正确的空闲块及双向链接。

**Case 2**：原链表非空时，将新增范围按地址纳入管理；若与原有空闲块物理相邻，合并为更大连续块，否则保留为独立块。

**Case 3**：`n == 0` 或交付范围包含非保留页等违反约定的情况，应以框架断言拒绝，不把不合法区域继续登记为空闲内存。

**Requirements**：支持合法的多次登记；块长和空闲页总数只按本次新增页数增长。无需负责修复 DTB、初始化缺失或调用者提供任意损坏指针的问题。

## best_fit_alloc_pages

**Pre-Condition**：申请页数为 `n`，正常调用要求 `n > 0`；管理器已初始化，已有空闲结构有效，或正处于既有测试约定的临时隔离状态。

**Post-Condition**：成功返回分配范围首个物理页的 `Page *`；失败返回 `NULL`。无论哪种情况，都不改变其他仍在使用的分配范围，不操作页表映射。

**Case 1：存在恰好匹配的块。**选择长度为 `n` 的候选；若多个候选长度相同，选择物理地址最小的块。移除其空闲块头身份，返回该块起点，空闲页数减少 `n`，不建立零长度剩余块。

**Case 2：没有恰好匹配，但存在更大的块。**在所有长度大于 `n` 的候选中选长度最小者，长度相同时选地址最小者。从所选块的低地址端分配精确 `n` 页，剩余范围成为一个正确的空闲块，保持地址有序与状态一致，空闲页数减少 `n`。

**Case 3：资源不足或没有合适连续块。**当 `n > nr_free`，或虽然总空闲页数足够但没有单个块满足申请，或链表为空时，返回 `NULL`，不改变链表、页面元数据和空闲计数。特别是测试暂时清空链表而尚未清零计数时，也必须安全返回 `NULL`。

**Case 4：申请 0 页。**触发断言，不把它当作成功分配或合法空操作。

**Requirements**：

必须比较候选块的大小；除找到无需继续比较的最优候选等正确情形外，不能遇到第一个足够大的块就直接返回。
返回范围内的页不带保留或空闲块头标记，引用计数为 0；这些状态符合本实验契约，不代表给页表设置了某种访问权限。
用描述符指针表示页范围，不能将其强转为数据区地址返回。保存并正确使用分割前块长，不能因覆盖元数据而算错剩余页数。
不要求清零被分配物理页的数据内容，不要求改动引用计数的全局生命周期设计。时间和空间复杂度不设额外指标，优先保证行为可验证。

## best_fit_free_pages

**Pre-Condition**：`n > 0`，`[base, base+n)` 是描述符数组内连续、未越界的有效页范围；页面已分配、可由调用者归还、不含保留页且不与已有空闲块重叠，调用者保证这些页不再被使用。合法归还可以是原申请的一部分，也可以覆盖若干次申请形成的连续已分配范围。

**Post-Condition**：这 `n` 页加入空闲集合，引用计数清零，空闲页数只增加 `n`。按地址形成正确链表，所有可与归还范围连接的相邻空闲块完成合并，失效的旧块头不再留在链表中。

**Case 1：链表为空。**归还范围成为唯一空闲块。

**Case 2：左右均不相邻。**归还范围作为独立块插入正确地址位置，支持链表头部、中间和尾部的插入。

**Case 3：仅与前驱或仅与后继相邻。**与相邻的一侧合并，保留合并后最低地址处的块头，长度为参与块长度之和。

**Case 4：与前驱和后继均相邻。**三段合成一段，最终块头位于三段最低地址，长度为三段之和；合并一次之后仍须正确识别另一侧邻居。

**Case 5：参数违反基本约定。**`n == 0`、待归还页带保留标记或带已有空闲块头标记等情况应由断言拒绝。不能为了绕过错误清掉断言，也不应误把合法的子区间归还判为非法。

**Requirements**：

物理相邻以“前块起点加前块页数等于后块起点”判定；链表位置相邻本身不构成合并依据。
归还只增加一次 `n`；移除旧头节点、合并长度不再增加计数，不能对页做重复归还。
`PG_property=0` 和 `ref=0` 都不能单独证明可释放。基础实现依赖合法调用前提及既有断言，不声称它已检测所有重复释放，尤其是空闲块内部页的重复释放。
不要求建立每次申请的历史记录；不得因此拒绝现有测试的范围释放方式。

## best_fit_nr_free_pages

**Pre-Condition**：管理器已初始化。

**Post-Condition**：返回当前维护的空闲物理页总数，单位为页，不是空闲块数量或字节数。

**Requirements**：该接口只查询，不改变链表、计数和页面状态，不通过扫描重算来覆盖测试临时保存或恢复的状态。

## best_fit_pmm_manager 注册与 init_pmm_manager 接入

**Pre-Condition**：所有回调的签名与 `struct pmm_manager` 一致；已有 `best_fit_check()` 在使用前可见；目标头文件已经提供管理器外部声明。

**Post-Condition**：注册对象的每个函数指针均绑定到正确实现，检查回调绑定现有测试；`init_pmm_manager()` 选择 Best-Fit，并调用它的初始化接口，之后对外分配、释放和检查均转发到 Best-Fit。

**Requirements**：保留原有名称输出，正常启动应出现 `memory management: best_fit_pmm_manager`；不能只改显示名称而仍调用 First-Fit。不得绕过 `pmm_manager->check()` 或改动 `page_init()` 的调用顺序。

## 验收场景与解释要求

**Pre-Condition**：上述实现和接入完成；动态检查还要求配套 RISC-V 工具链、QEMU 与功能模块一初始化可用。

**Post-Condition**：保留并通过既有 `basic_check()`、`best_fit_check()`；能正常编译、启动，并在依赖满足时完成工程提供的评分检查。若依赖不满足，只报告实际完成程度与阻塞点，不伪造结论。

**Case 1：验证最佳适应而非首次适应。**用连续 5 页中的第 1～2 页和第 4 页分别形成 2 页块与 1 页块。申请 1 页时应选择后面的 1 页块，随后申请 2 页仍能使用前面的 2 页块。这是现有测试的关键辨别场景，应解释其为何能区分两种算法。

**Case 2：验证分割、合并与计数守恒。**结合既有检查，说明恰好分配、部分分配、空链表、无足够连续块、左右合并，以及全部归还后块组织和空闲总数恢复的行为。尤其核对测试清空、恢复状态与分配子区间的用法。

**Case 3：前置依赖缺失。**如 `page_init()` 尚未实现，或工具链、QEMU 不可用，指出具体位置和实际错误；在不扩大修改范围的前提下完成接口、逻辑及差异审查，明确哪些运行结果尚未验证。

**Requirements**：不修改既有测试，不新增到内核正常启动路径的额外自测；未覆盖的边界应如实列为验证限制。解释优化时，说明按地址有序链表如何帮助回收合并，以及为加快 Best-Fit 搜索新增大小索引时为何必须同步维护两种关系。
