# 实验二扩展任务：SLUB 进阶测试函数

[PROMPT]
**任务**：修改 `kern/mm/slub.c` 中的 `slub_check` 函数，为 SLUB 分配器提供更详尽的边界测试。
**操作要求**：你必须在项目中修改实际文件，保留原有的 `//lab2 challenge-1` 注释。不得修改第一份 Prompt 中实现的核心逻辑。
**输出要求**：直接修改 `slub_check` 的内部逻辑。

[RELY]
```c
void *kmem_cache_alloc(struct kmem_cache *cachep);
void kmem_cache_free(struct kmem_cache *cachep, void *objp);
```

[GUARANTEE]
完善 `slub_check` 测试函数。

[SPECIFICATION]
## slub_check 函数
**Post-Condition**: 测试通过后输出 "slub_check() succeeded!"。
**Case 1 (跨页分配测试)**:
- 创建一个极小的对象缓存（如 16 字节）。一页 4KB 最多容纳 256 个对象。连续分配超过 300 个对象，强制触发分配新的物理页（多个 Slab）。
- 验证所有 300 个指针均非空且互不相同。
- 全部释放后，再次分配，验证是否能正常复用。
**Case 2 (混合大小测试)**:
- 同时创建 32B、64B、256B 的 cache。
- 交替从这三个 cache 中分配和释放对象，验证不同 cache 之间的空闲链表不会互相干扰。
**Case 3 (异常与边界)**: 
- 验证对齐：检查分配出来的指针地址是否按 8 字节对齐。
**Requirements**:
- 必须使用 `assert` 验证指针的合法性和对齐。
- 必须使用 `cprintf` 打印清晰的测试阶段信息。