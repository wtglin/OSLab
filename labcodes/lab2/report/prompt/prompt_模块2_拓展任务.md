# 实验二扩展任务：SLUB 内存对象分配模块（实现）

[PROMPT]
**任务**：在 `kern/mm/slub.c` 和 `kern/mm/slub.h` 中从零实现一个简化版的 SLUB (Simple List of Unused Blocks) 内存对象分配模块，并在 `kern/init/init.c` 的 `kern_init()` 函数中调用 `slub_check()` 进行测试。SLUB 采用两层架构：底层调用物理页分配器获取整页，上层将页切分为固定大小的小对象（如 32B, 64B, 128B），并用空闲链表管理。

**操作要求**：你必须在项目中修改实际文件，而不是仅展示代码。你需要从零创建这两个文件。**不得修改** `kern/mm/pmm.h` 等头文件已有的接口。你需要自行设计 SLUB 的核心数据结构（如 `kmem_cache`）和内部静态函数。最后，在 `kern/init/init.c` 的初始化流程中调用 `slub_check()`。

**输出要求**：直接在新建的文件中写入完整实现，并在 `init.c` 中接入。使用下面 `[RELY]`、`[GUARANTEE]`、`[SPECIFICATION]` 的信息。确保内核能够正常编译并运行。

[RELY]
底层物理页分配接口（`kern/mm/pmm.h`）：
```c
struct Page *alloc_pages(size_t n);             // 申请 n 个连续物理页
void free_pages(struct Page *base, size_t n);   // 释放物理页
static inline uintptr_t page2pa(struct Page *page); // 获取物理地址
extern uint64_t va_pa_offset;                   // 虚拟地址与物理地址的偏移量
```

**关键提示**：当你调用 `alloc_pages` 申请到新页时，页的虚拟地址计算方式为 `void *vaddr = (void *)(page2pa(page) + va_pa_offset);`。你必须用这个虚拟地址来进行内存切分。

[GUARANTEE]
必须在 `slub.c` 中实现以下接口，并在 `slub.h` 中声明：
```c
struct kmem_cache;

struct kmem_cache *kmem_cache_create(const char *name, size_t size);
void *kmem_cache_alloc(struct kmem_cache *cachep);
void kmem_cache_free(struct kmem_cache *cachep, void *objp);
void slub_check(void);
```

你可以根据需要添加：
- 模块内部的静态辅助函数（如初始化 slab、分配新 slab 等）。
- 模块内部的静态变量（如全局的 cache 数组或链表）。

[SPECIFICATION]
## kmem_cache_create 函数
**Pre-Condition**: `size > 0`，`name` 不为空。
**Post-Condition**: 返回一个指向新创建的内存缓存池控制块的指针。
**Case 1**: 
- 分配并初始化一个 `struct kmem_cache`。记录对象大小、对齐大小。初始化该 cache 内部的空闲对象链表为空。

## kmem_cache_alloc 函数
**Pre-Condition**: `cachep` 指针有效。
**Post-Condition**: 返回一块大小至少为指定 `size` 的内存块指针。
**Case 1 (有空闲对象)**: 
- 从 `cachep` 的空闲链表中摘取一个对象并返回。
**Case 2 (无空闲对象，需分配新 Slab)**: 
- 调用 `alloc_pages(1)` 申请一页（4KB）。
- 使用 `page2pa` 和 `va_pa_offset` 将 Page 转换为虚拟地址。
- 将该页切分为若干 `size` 大小的对象（**注意：对象大小需 8 字节对齐**）。
- 利用空闲对象的内存本身存储 `next` 指针，串成链表，然后返回第一个对象。

## kmem_cache_free 函数
**Pre-Condition**: `cachep` 有效，`objp` 是该 cache 分配出去的对象。
**Post-Condition**: 将对象归还给 `cachep`。
**Case 1**: 
- 将 `objp` 插入到 `cachep` 的空闲链表头部。

## slub_check 函数
**Post-Condition**: 打印测试成功信息（如 "slub_check() succeeded!"）。
**Case 1 (基本分配与释放)**: 
- 创建一个对象大小为 32 字节的 cache，连续分配 3 个对象，验证返回指针非空且不重叠。
- 释放这 3 个对象，再次分配，验证底层能够复用这些内存块。
**Requirements**: 
- 必须使用 `assert` 检查指针合法性。