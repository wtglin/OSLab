[PROMPT]

**任务**：
在`kern\mm\pmm.c`中标有`//lab2 function1 YOUR CODE`的位置，实现`static void page_init(void)`函数，完成物理内存探测与页描述符初始化功能。
这个函数需要处理以下场景：
物理内存探测：使用设备树提供的内存基址和大小确定物理内存范围
描述符布局：正确设置va_pa_offset、npage和pages，并区分Page描述符地址与物理地址
已用空间排除：不把OpenSBI、内核镜像和Page描述符数组占用的页面交给物理内存管理器
页面边界处理：正确处理可管理上界、页面向上或向下对齐以及物理页号转换
异常处理：设备树信息无效时终止初始化，没有可用完整页面时不调用init_memmap()

**操作要求**：必须在项目中修改实际文件，而不是仅展示代码。
使用已有的 `get_memory_base()` 和 `get_memory_size()` 读取物理内存基址与大小。

**输出要求**：直接在标记位置写入完整实现，保留文件中现有代码与测试函数
使用下列 [RELY]、[GUARANTEE] 和 [SPECIFICATION] 中的信息，以工程真实代码为准。
实现要能通过`tools/test_lab2.c`文件下 `test_page_init()`的测试函数，并正常编译运行。
编译运行时输出探测到的物理内存基址、大小和地址范围。


[RELY]

查询物理内存基址和大小接口`get_memory_base(),get_memory_size()`(`kern\driver\dtb.h`)
```c
uint64_t get_memory_base(void);
uint64_t get_memory_size(void);
```

内存相关地址宏定义、页状态宏定义与页描述符结构(`kern\mm\memlayout.h`)
```c
#define KERNBASE            0xFFFFFFFFC0200000
#define PHYSICAL_MEMORY_END         0x88000000
#define PHYSICAL_MEMORY_OFFSET      0xFFFFFFFF40000000


struct Page {
    int ref;                        // page frame's reference counter
    uint64_t flags;                 // array of flags that describe the status of the page frame
    unsigned int property;          // the num of free block, used in first fit pm manager
    list_entry_t page_link;         // free list link
};

#define PG_reserved                 0       // if this bit=1: the Page is reserved for kernel, cannot be used in alloc/free_pages; otherwise, this bit=0 
#define PG_property                 1       // if this bit=1: the Page is the head page of a free memory block(contains some continuous_addrress pages), and can be used in alloc_pages; if this bit=0: if the Page is the the head page of a free memory block, then this Page and the memory block is alloced. Or this Page isn't the head page.

#define SetPageReserved(page)       ((page)->flags |= (1UL << PG_reserved))
#define ClearPageReserved(page)     ((page)->flags &= ~(1UL << PG_reserved))
#define PageReserved(page)          (((page)->flags >> PG_reserved) & 1)
```

页面大小、偏移常量(`kern\mm\mmu.h`)
```c
#define PGSIZE          4096                    // bytes mapped by a page
#define PGSHIFT         12                      // log2(PGSIZE)

// physical/virtual page number of address
#define PPN(la) (((uintptr_t)(la)) >> PGSHIFT)
```

页相关函数与全局变量（`kern\mm\pmm.c`、`kern\mm\pmm.h`）
```c
struct Page *pages;
// amount of physical memory (in pages)
size_t npage = 0;
// the kernel image is mapped at VA=KERNBASE and PA=info.base
uint64_t va_pa_offset;
// memory starts at 0x80000000 in RISC-V
// DRAM_BASE defined in riscv.h as 0x80000000
const size_t nbase = DRAM_BASE / PGSIZE;

// physical memory management
const struct pmm_manager *pmm_manager;

// init_memmap - call pmm->init_memmap to build Page struct for free memory
static void init_memmap(struct Page *base, size_t n) {
    pmm_manager->init_memmap(base, n);
}


#define PADDR(kva)                                                 \
    ({                                                             \
        uintptr_t __m_kva = (uintptr_t)(kva);                      \
        if (__m_kva < KERNBASE) {                                  \
            panic("PADDR called with invalid kva %08lx", __m_kva); \
        }                                                          \
        __m_kva - va_pa_offset;                                    \
    })

static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }

static inline uintptr_t page2pa(struct Page *page) {
    return page2ppn(page) << PGSHIFT;
}


static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }

static inline int page_ref_inc(struct Page *page) {
    page->ref += 1;
    return page->ref;
}

static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
}
```

页面对齐函数(`libs/defs.h`)
```c
#define ROUNDDOWN(a, n) ({                                          \
            size_t __a = (size_t)(a);                               \
            (typeof(a))(__a - __a % (n));                           \
        })

/* Round up to the nearest multiple of n */
#define ROUNDUP(a, n) ({                                            \
            size_t __n = (size_t)(n);                               \
            (typeof(a))(ROUNDDOWN((size_t)(a) + __n - 1, __n));     \
        })
```

异常终止接口`panic(...)`(`kern/debug/assert.h`)
```c
#define panic(...)                                      \
    __panic(__FILE__, __LINE__, __VA_ARGS__)
```

[GUARANTEE]

必须实现的接口：

```c
static void page_init(void);
```

该由`pmm_init()` 调用，不接收参数，不返回结果，建立物理页描述符布局并注册初始空闲页面。


你可以根据需要添加：
本模块内部使用的 `static` 辅助函数。
模块内部使用的`static`变量


[SPECIFICATION]

## page_init 函数

**Pre-Condition**：
- 内核已初始化，地址映射有效。
- `dtb_init()` 已执行，两个查询接口可用。
- pmm_manager已初始化，且 `nr_free_pages()`为 0。

**Post-Condition**：

**Case 1：**
若内存信息有效，且有完整空闲页，`get_memory_base() == DRAM_BASE`、`get_memory_size() > 0`，地址计算无溢出，且Page描述符数组未超出范围、仍有完整空闲页时，应正确设置 `va_pa_offset`、`npage` 和 `pages`，初始化描述符并调用 `init_memmap()` 注册空闲页。

**Case 2：**
若物理内存信息无效，当 `get_memory_base() != DRAM_BASE`、`get_memory_size()<=0`、或内存末端计算溢出时，应调用 `panic()` 终止初始化。

**Case 3：**
若内核、描述符数组无法完整放入按页对齐后的管理范围时，应调用 `panic()`初始化终止。

**Case 4**
若没有完整空闲页，`nr_free_pages()` 为 0；正常返回，不调用 `init_memmap()`。