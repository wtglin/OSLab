# 实验二任务三：Buddy System (伙伴系统) Prompt

[PROMPT]
**任务**：在 `kern/mm/buddy_pmm.c` 和 `kern/mm/buddy_pmm.h` 中从零实现 Buddy System (伙伴系统) 连续物理内存分配模块，并注册 `buddy_pmm_manager`。修改 `kern/mm/pmm.c` 中的 `init_pmm_manager` 函数，使其替换当前内核使用的 First-Fit 物理内存管理器。buddy算法原理大致是将物理内存按 2 的 n 次幂划分成存储块，分配时若块过大则对半拆分，释放时若伙伴块空闲则递归合并。

**操作要求**：你必须在项目中修改实际文件，而不是仅展示代码。你需要从零创建 `kern/mm/buddy_pmm.c` 和 `kern/mm/buddy_pmm.h` 两个文件。**不得修改** `kern/mm/memlayout.h`、`kern/mm/pmm.h`、`libs/list.h` 等头文件已有的接口与结构体（如 `struct Page`, `free_area_t` 等）。你需要自行设计 Best-Fit 分配器的内部状态（如静态的 `free_area_t` 数组）和相关管理函数（如找伙伴、计算 order 等，建议设为 static），不得新增跨文件的新接口。

**输出要求**：直接在新建的文件中写入完整实现，并在 `pmm.c` 中接入。使用下面 `[RELY]`、`[GUARANTEE]`、`[SPECIFICATION]` 的信息，若工程真实签名与样本不一致，以当前工程为准。实现必须符合 `buddy_check()` 所依赖的状态约定，能通过测试并正常编译运行。实现后还需在 `kern/mm/pmm.c` 的 `init_pmm_manager()` 中，把 `pmm_manager` 指向 `&buddy_pmm_manager`，确保内核运行与检查的是 Buddy System 实现。

[RELY]
`struct pmm_manager`（`kern/mm/pmm.h`），其成员均为函数指针，Buddy 需按此注册：
```c
struct pmm_manager {
    const char *name;                          // 管理器名字
    void (*init)(void);                        // 初始化内部数据结构
    void (*init_memmap)(struct Page *base, size_t n); // 依据初始空闲区建立管理结构
    struct Page *(*alloc_pages)(size_t n);     // 分配 >=n 个连续页
    void (*free_pages)(struct Page *base, size_t n);  // 释放以 base 为首的连续 n 页
    size_t (*nr_free_pages)(void);             // 返回空闲页数目
    void (*check)(void);                       // 正确性检查
};
```

已由 `kern/mm/memlayout.h` 提供 与 First-Fit 相同的页结构，Buddy 应使用同样的约定，否则无法编译与通过：
```c
struct Page {
    int ref;                        // page frame's reference counter
    uint64_t flags;                 // 状态位 (PG_reserved / PG_property)
    unsigned int property;          // 空闲块大小（页数），供 alloc/free 使用，Buddy 中可存 order
    list_entry_t page_link;         // 空闲链表节点
};

typedef struct {
    list_entry_t free_list;         // 空闲块链表头
    unsigned int nr_free;           // 空闲页总数
} free_area_t;
```

链表接口（`libs/list.h`）：`list_init`、`list_add`、`list_add_before`、`list_del`、`list_empty`、`list_next`、`list_prev`，以及 `le2page`（`kern/mm/memlayout.h`）。

地址转换相关内联函数（`kern/mm/pmm.h`）：
```c
static inline ppn_t page2ppn(struct Page *page);  // 获取物理页号
static inline struct Page *pa2page(uintptr_t pa); // 物理地址转 Page 指针
```

[GUARANTEE]
必须实现以下接口并注册：
```c
static void buddy_init(void);
static void buddy_init_memmap(struct Page *base, size_t n);
static struct Page *buddy_alloc_pages(size_t n);
static void buddy_free_pages(struct Page *base, size_t n);
static size_t buddy_nr_free_pages(void);
static void buddy_check(void);

const struct pmm_manager buddy_pmm_manager = { ... }; // .name 应为 "buddy_pmm_manager"，.check 指向 buddy_check()
```

为了满足测试函数对 `free_area` 数组的引用，必须在模块内部定义：
```c
#define MAX_ORDER 11
static free_area_t free_area[MAX_ORDER];
```

你可以根据需要添加：
- 仅限在当前模块内存取的内部辅助函数（如计算阶数、查找伙伴等）；
- 模块内部的静态变量。

不得改动 `struct pmm_manager` 的成员签名；不允许新增跨文件的新接口。

[SPECIFICATION]
## buddy_init 函数
**Pre-Condition**: 无

**Post-Condition**: 初始化长度为 11 的 `free_area` 数组，将所有 `order` 对应的 `free_list` 置空，`nr_free` 清零。

**Requirements**: 无

## buddy_init_memmap 函数
**Pre-Condition**: `base` 指向一段连续的物理页，`n` 为该段页数。

**Post-Condition**: 这段连续内存被按 2 的幂次切分成多个块，并分别挂载到对应 `order` 的 `free_list` 上，`property` 记录了各自的阶数，总空闲页数被正确更新。

**Case 1**:
- 遍历 [base, base+n)，清空 `PG_reserved` 标志，重置 `ref` 为 0。
- 从 `n` 中循环提取最大的 2 的幂次块：每次找到最大的 `order` 使 `(1 << order) <= n`。设置首页 `PG_property`，`property = order`，插入 `free_area[order]`，`nr_free += (1 << order)`，`n` 减去该值。直到 `n` 为 0。

**Requirements**: 必须保证提取出的块大小严格为 2 的幂次。

## buddy_alloc_pages 函数
**Pre-Condition**: `n > 0`。

**Post-Condition**: 返回分配得到的起始 `Page` 指针，其包含至少 `n` 个连续页；若空间不足则返回 `NULL`。

**Case 1**:
- 计算目标阶数：向上取整找到最小的 `target_order` 使得 `(1 << target_order) >= n`。
- 从 `target_order` 开始向上遍历，找到第一个非空的 `free_area[i]` 链表。
- 将对应的块摘下，不断一分为二（拆分）：`i--`，将后半部分插入 `free_area[i]` 链表，前半部分继续拆分，直到 `i == target_order`。
- 将最终得到的块摘除，清除 `PG_property`，更新 `nr_free -= (1 << target_order)`，返回该 Page 指针。

**Case 2**:
- 若向上查找未找到任何可用块，直接返回 `NULL`。

**Requirements**: 分配的物理页大小必须满足请求的最小 2 的幂次大小。

## buddy_free_pages 函数
**Pre-Condition**: `base` 为要释放的连续内存块首页，`n` 为页数。

**Post-Condition**: 释放后的内存块能够和它的“伙伴”块递归合并，最终挂载到正确的 `free_list` 中，`nr_free` 被增加。

**Case 1**:
- 遍历释放的页，重置 `ref` 和 `flags`。
- 计算对应的 `order`（对称向上取整），设置 `base->property = order`，`SetPageProperty(base)`。
- 当 `order < MAX_ORDER - 1` 时循环：通过 `page2ppn(base)` 获取页号 `pfn`，通过 `buddy_pfn = pfn ^ (1 << order)` 计算伙伴页号，利用 `pa2page(buddy_pfn << 12)` 获取伙伴的 `Page`。
- 遍历 `free_area[order]` 链表，若找到伙伴块，将其从链表摘除；若伙伴地址小于 `base`，则更新 `base = buddy_page`；`order++`，继续循环。
- 合并结束后，将最终的 `base` 插入对应的 `free_area[order]`，更新 `nr_free`。

**Requirements**: 寻找伙伴必须通过 `page2ppn` 和 `pa2page` 的异或运算来完成。

## buddy_check 函数
**Pre-Condition**: 无

**Post-Condition**: 通过输出 `"buddy_check() succeeded!"` 表明基本测试通过。

**Case 1**:
- 申请 3 页内存，验证 `nr_free` 减少 4，释放后恢复。
- 申请两个 1 页块 A、B，先释放 A 再释放 B，验证它们能够成功合并为 2 页块。

**Case 2**:
- 申请超过当前空闲页数的内存，验证返回 `NULL`。

**Requirements**: 必须使用 `assert` 对关键状态进行检查。