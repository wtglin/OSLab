# 实验二任务三：Buddy System 测试函数完善 Prompt

[PROMPT]
**任务**：修改 `kern/mm/buddy_pmm.c` 中的 `buddy_check` 函数，将内部测试逻辑替换为更详尽的测试用例，以检验 Buddy System 分配和释放的正确性。
**操作要求**：你必须在项目中修改实际文件。请替换原先简单的测试逻辑，不得修改 `basic_check` 或其他已有的测试框架函数。
**输出要求**：直接进行文件操作，写出完整的 `buddy_check` 实现。

[RELY]
依赖的基础接口（已在 `kern/mm/pmm.h` 中声明）：
```c
struct Page *alloc_pages(size_t n);
void free_pages(struct Page *base, size_t n);
size_t nr_free_pages(void);
```

为了验证状态，你可以依赖以下断言和输出工具（注意包含相应头文件）：
```c
#include <assert.h>
#include <stdio.h>
```

[GUARANTEE]
必须实现或修改的接口：
```c
static void buddy_check(void);
```
你可以根据需要添加仅在 `buddy_check` 内部使用的局部变量，但不能新增跨文件的全局接口。

[SPECIFICATION]
## buddy_check 函数
**Pre-Condition**: 无。

**Post-Condition**: 
- 所有测试用例执行完毕且无误后，打印 `"buddy_check() succeeded!"`。

**Case 1 (不同大小分配与释放)**: 
- 记录初始空闲页数 `nr_free_store`。分别申请 1 页、2 页、4 页，验证返回非 NULL，且页引用计数正常。随后逐一释放，验证 `nr_free_pages()` 恢复为 `nr_free_store`。

**Case 2 (非 2 的幂次分配)**: 
- 申请 3 页内存，验证底层是否实际分配了 4 页（即空闲页数减少了 4 页）。验证返回的指针可用。释放后验证空闲页数恢复。

**Case 3 (伙伴合并验证)**: 
- 连续申请两个 1 页的块 A 和 B（它们必须是相邻的伙伴）。
- 先释放 A，检查 `nr_free_pages()` 增加 1。
- 再释放 B，验证它们是否能够成功合并。合并后，通过检查 `free_area` 数组或 `nr_free_pages()` 确认它们作为 2 页的块存在。

**Case 4 (异常与边界)**: 
- 申请超过当前总空闲页数的内存（如 `nr_free_pages() + 1`），验证返回 `NULL`，且系统不崩溃。

**Requirements**: 
- 每一步分配或释放后，都要用 `assert` 验证空闲页数量的变化是否符合预期。
- 必须有清晰的 `cprintf` 输出说明当前正在测试什么（例如：`cprintf("alloc_pages(3) test passed!\n");`）。