[PROMPT]

**任务**：在 `kern/mm/pmm.c`的`//LAB4 function1 YOUR CODE` 标记下实现虚拟内存页操作功能，利用现有多级页表建立、更新和删除线性地址到物理页的映射。

- `page_insert`负责建立或更新映射：将指定物理页映射到目标线性地址，并设置调用者要求的权限。目标地址已有映射时，分别处理映射到同一物理页和映射到不同物理页的情况。无法分配所需的页表页时，返回 -E_NO_MEM，保持原有映射状态。
- `page_remove`负责删除映射：撤销目标线性地址已有的映射；目标地址没有有效映射时直接返回。

**操作要求**：必须在项目中修改实际文件，而不是仅展示代码。仅在 `//LAB4 function1 YOUR CODE` 标记下补全这两个函数。保留已有函数和测试代码。

**输出要求**：直接在标记位置写入完整实现，保留文件中现有代码与测试函数，使用下列 [RELY]、[GUARANTEE] 和 [SPECIFICATION] 中的信息，以工程真实代码为准。每次修改映射后，页表项、物理页引用计数和 TLB 状态应保持一致。保证通过 `check_pgdir`、`check_boot_pgdir` 和 `test_lab4_pmm_basic` 中的检查并正常编译运行。

[RELY]

**页表项类型与权限位**（`kern/mm/memlayout.h`、`kern/mm/mmu.h`）
```c
typedef uintptr_t pte_t;
typedef uintptr_t pde_t;

#define PTE_V 0x001
#define PTE_R 0x002
#define PTE_W 0x004
#define PTE_U 0x010
```

**物理页描述符与页表相关全局变量**（`kern/mm/memlayout.h`、`kern/mm/pmm.h`）
```c
struct Page {
    int ref;
    uint_t flags;
    unsigned int property;
    list_entry_t page_link;
    list_entry_t pra_page_link;
    uintptr_t pra_vaddr;
};

extern struct Page *pages;
extern pde_t *boot_pgdir_va;
```

**页表项查找与转换接口**（`kern/mm/pmm.h`、`kern/mm/pmm.c`）
```c
pte_t *get_pte(pde_t *pgdir, uintptr_t la, bool create);
static inline ppn_t page2ppn(struct Page *page);
static inline pte_t pte_create(uintptr_t ppn, int type);
static inline struct Page *pte2page(pte_t pte);
```

**物理页引用计数及分配、回收接口**（`kern/mm/pmm.h`）
```c
static inline int page_ref_inc(struct Page *page);
static inline int page_ref_dec(struct Page *page);
static inline void set_page_ref(struct Page *page, int val);
#define alloc_page() alloc_pages(1)
#define free_page(page) free_pages(page, 1)
```


**TLB 失效接口与错误码**（`kern/mm/pmm.h`、`kern/mm/pmm.c`）
```c
void tlb_invalidate(pde_t *pgdir, uintptr_t la);
static inline void flush_tlb();
#define E_NO_MEM 4
```


[GUARANTEE]

必须实现的接口（要与 `kern/mm/pmm.h` 一致）：

```c
int page_insert(pde_t *pgdir, struct Page *page, uintptr_t la, uint32_t perm);
void page_remove(pde_t *pgdir, uintptr_t la);
```

你可以根据需要添加：
本模块内部使用的 `static` 辅助函数。
模块内部使用的`static`变量

[SPECIFICATION]

## `page_insert`

**Pre-Condition**：物理内存管理已初始化，`pgdir` 指向有效的页表根，`page` 是已分配的物理页。`la` 为目标线性地址，映射以它所在的页为单位。

**Post-Condition**：成功返回 `0`。目标页表项指向指定物理页，权限位按本次传入的 `perm` 设置。

- **Case 1：目标地址没有有效映射。** 建立映射，目标物理页的引用计数加一。
- **Case 2：目标地址已映射到同一物理页。** 更新页表项中的权限，物理页的引用计数保持不变。
- **Case 3：目标地址已映射到另一物理页。** 用新映射替换原映射，新页的引用计数加一，原页的引用计数减一。原页的引用计数减到零时将其归还给分配器，有剩余引用时保留该页。
- **Case 4：所需的中间页表页分配失败。** 返回 `-E_NO_MEM`，目标地址的映射状态和数据页的引用计数保持不变。

## `page_remove`

**Pre-Condition**：`pgdir` 指向有效的页表根，`la` 为要撤销映射的线性地址，操作以它所在的页为单位。

**Post-Condition**：目标地址没有有效映射，其他地址的映射保持原样。对同一地址重复调用与删除一次的结果相同。

- **Case 1：目标地址没有有效映射。** 无论是中间页表缺失，还是目标页表项无效，均直接返回，页表和物理页引用计数保持不变。
- **Case 2：目标地址有有效映射。** 清除目标页表项，将原物理页的引用计数减一。计数减到零时归还该页，有剩余引用时保留该页。

