# 操作系统实验报告

## 实验基本信息

| 项目 | 内容 |
|------|------|
| **实验名称** | Lab 2: [实验名称] |
| **小组成员** | 2411153-李江楠 、2413115-刘卓明、2411248-沈东阳 |
| **完成日期** | 2026-10-25 |

### 小组分工

| 成员 | 负责的练习/模块 |
|------|----------------|
| 2413115-刘卓明 | [功能模块一：物理内存初始化功能] |
| 学号2-姓名2 | [练习或模块名称] |
| 学号3-姓名3 | [练习或模块名称] |

---

## 一、实验目的

<!-- 说明本次实验的主要目标和预期成果 -->

本实验的主要目的是：

1. 理解页表的建立和使用方法
2. 理解物理内存的管理方法
3. 理解页面分配算法

---

## 二、实验环境

你们使用的 AI 工具

| 成员 | AI 编程工具 | 底层模型 | 备注 |
|------|------------|---------|------|
| 2411153-李江楠 | codex桌面应用 | GPT-6 |  |
| 2413115-刘卓明 |codex（VS Code插件） |GPT-6 | |
| 2411248-沈东阳 | codex （VS Code插件） | DeepSeek-v4flash ||

---

## 三、实验整体逻辑分析

### 2.1 本章节的逻辑主线

- 本章围绕物理内存管理核心主题展开，首先建立物理地址与虚拟地址的映射，实现页表的地址转换，如何内核通过设备树获取 RAM 的位置和大小，将内存按页划分，并建立页描述符记录每个物理页的状态。最好研究如何分配这些物理页，通过 First-Fit、 Best-Fit 和 Buddy System等算法实现。

- 整个实验主要解决3个问题：

1. 物理内存在哪、有多大？

物理内存探测：操作系统不能把内存大小写死，必须通过解析 OpenSBI 传递的设备树，动态探测出物理内存的起始地址和大小，并完成虚拟地址到物理地址映射的初始化。

2. 如何记录每一页的状态？

描述符布局：物理内存按 4KB 划分为页。操作系统需要在内核镜像（end）之后，按页对齐分配一块连续的物理内存来存放 struct Page 描述符数组。给每一个物理页记录是被占用还是空闲。

3. 如何高效地分配与回收？

分配算法：实现 pmm_manager 框架的具体分配算法，从 First-Fit 算法到 Best-Fit，还有更高级的 Buddy System 和 SLUB，以满足从整页分配到任意大小内存分配的需求。

### 2.2 功能的逐步实现

1. 首先实现**虚实地址映射**。在 entry.S 中分配并初始化 Sv39 根页表，将内核的高虚拟地址映射到物理地址，随后写入 satp 寄存器开启分页机制并跳转到 C 语言入口。之所以首先实现这个，是因为修改链接脚本后内核的符号地址均变成了高虚拟地址，此时 CPU 仍处于 Bare 模式，如果不先建立页表完成地址转换，CPU 连内核指令都无法正确取指和建立栈空间。
2. 接着实现**物理内存探测**。在进入内核初始化后，解析 OpenSBI 传入的设备树，提取出物理内存的起始地址与总大小，并初始化全局虚实偏移量。之所以接着实现这个，是因为准确获知硬件实际提供的物理内存范围和边界信息，才能为后续的页面划分提供数据支撑。
3. 然后完成**页描述符初始化与空闲区注册**。在内核映像结尾（end）之后按页对齐放置 struct Page 描述符数组，将 OpenSBI、内核镜像及该数组自身占用的物理页全部标记为保留，并将剩余的完整可用页挂载到空闲双向链表上。之所以实现这个功能，是因为获取硬件内存信息后，我们需要建立数据结构来记录每个 4KB 物理页的状态；同时，必须精确排除系统核心组件和底层固件占用的空间以防被分配覆盖，而建立好的空闲链表则直接为后续的分配算法准备好了数据池。
4. 最后实现**物理内存分配算法**。我们先跑通First-Fit，随后实现Best-Fit，并进一步完成伙伴系统。掌握空闲块如何组织、分配时如何查找和拆分，以及释放后如何合并相邻空闲块。
---

## 四、实验内容与实现

### 功能模块1：[物理内存初始化功能]

**负责人：** [2413115-刘卓明]

#### 模块功能描述

**需要实现/修改的函数：**

```c
static void page_init(void);
```

**功能说明：**

本模块负责物理内存管理的初始化，为后续页面分配和回收提供基础。page_init() 根据设备树提供的内存信息，进行物理内存探测，设置虚实地址偏移、物理页号上界和页描述符数组，建立物理页与描述符之间的对应关系。初始化时，需要限制管理上界并处理页面对齐，保留 OpenSBI、内核镜像和描述符数组占用的页面，只将剩余完整页面登记为空闲页。设备树信息无效或内存无法容纳必要数据时，终止初始化；没有完整空闲页时，保持空闲区为空，不进行注册。该函数由 pmm_init() 在物理内存管理器初始化后调用，通过 init_memmap() 将空闲页面交给当前管理器。后续的 alloc_pages() 和 free_pages() 依赖这里建立的初始状态完成分配与回收。

#### 最终提示词

以下是经过迭代优化后，最终成功实现该功能的提示词：

````markdown
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
    int ref;                        // page frame's 
    uint64_t flags;                 // array of flags 
    unsigned int property;          // the num of free 
    list_entry_t page_link;         // free list link
};
#define PG_reserved                 0       
#define PG_property                 1 
#define SetPageReserved(page)       ((page)->flags |= (1UL << PG_reserved))
```

页面大小、偏移常量(`kern\mm\mmu.h`)
```c
#define PGSIZE          4096                    // bytes mapped by a page
#define PGSHIFT         12                      // log2(PGSIZE)
#define PPN(la) (((uintptr_t)(la)) >> PGSHIFT)
```

页相关函数与全局变量（`kern\mm\pmm.c`、`kern\mm\pmm.h`）
```c
struct Page *pages;
size_t npage = 0;
uint64_t va_pa_offset;
const size_t nbase = DRAM_BASE / PGSIZE;
const struct pmm_manager *pmm_manager;
static void init_memmap(struct Page *base, size_t n)
#define PADDR(kva)
static inline void set_page_ref(struct Page *page, int val) 
static inline struct Page *pa2page(uintptr_t pa) 
```

页面对齐函数(`libs/defs.h`)
```c
#define ROUNDDOWN(a, n) 
#define ROUNDUP(a, n) 
```

异常终止接口`panic(...)`(`kern/debug/assert.h`)
```c
#define panic(...)
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

````

#### 实现迭代过程

本模块的实现经历了 [1] 次迭代，过程如下：

---

##### 第一次迭代

**最终结果：**

经过 [1] 次迭代，该模块最终：
- ✅ 编译通过
- ✅ 所有相关测试通过
- ✅ 功能符合预期

**关键改进点总结（如有）：**
1. [改进点1：例如，在 [RELY] 中补充了完整的系统调用号定义]
2. [改进点2：例如，在 [SPECIFICATION] 中明确了异常处理的边界条件]
3. [改进点3：例如，增加了对用户指针合法性检查的要求]
---

### Challenge：[硬件的可用物理内存范围的获取方法]

**负责人：** [2413115-刘卓明]

如果 OS 无法提前知道当前硬件的可用物理内存范围，请问你有何办法让 OS 获取可用物理内存范围？

**运行时地址空间探测**：如果操作系统运行在没有任何固件提供信息的情况下，可以通过不断的写入读取数据来测试，设计相应的异常捕捉机制，当访问超出物理内存范围的地址时，会引发异常，通过这个来确定物理地址边界。

---

### 练习：[练习标题]

**负责人：** [学号-姓名]

[按照练习的具体要求进行解答]

---

### Challenge：[硬件的可用物理内存范围的获取方法]

**负责人：** [学号-姓名]

[按照Challenge的具体要求进行解答]

---

### 分支任务：gdb 调试页表查询过程


---

## 五、测试与验证

<!-- 根据该实验的具体情况，提供完整的测试运行截图，应包含：
- 编译及运行成功的输出（make qemu），可能有多个
- 测试通过的结果（make grade），只有一个
-->

**测试截图：**

![测试结果截图](./images/test_result.png)

---

## 六、实验总结与收获

### 对操作系统的理解

1. 列出你们认为本实验中重要的知识点，以及与对应的 OS 原理中的知识点，并简要说明二者的含义、关系和差异
2. 列出你们认为 OS 原理中很重要、但在本实验中没有对应上的知识点

### AI 协作开发的经验

[写出你们在与 AI 协作过程中实际收获的经验或者感悟]

---

