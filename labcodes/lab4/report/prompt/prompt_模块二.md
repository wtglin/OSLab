[PROMPT]

**任务**　在 `lab4/lab4_new/kern/process/proc.c` 实现 Lab4 功能模块二「内核线程创建」。在 `//LAB4 function2 YOUR CODE` 和 `//LAB4 function3 YOUR CODE` 两个标记之间补全下列六个函数。启动时把当前执行流登记为 `idleproc`，再由它创建具有独立内核栈的 `initproc`。模块完成的时点是两个线程均已就绪，CPU 仍在执行 `idleproc`。

**操作要求**　执行此提示词时必须修改上述实际文件，复用已有辅助函数。保留模块标记，提交时仅将模块二标记中的 `YOUR CODE` 替换为本人学号。修改范围限于模块二，模块一的页表管理、模块三的调度与切换、Lab2/Lab3 的前置依赖以及评分程序均在本次范围之外。

**输出要求**　依据以下接口及行为规格完成实现，列出修改文件，简述子线程首次执行所依赖的寄存器设置，以及创建失败时如何回收资源。无需编译、运行或评分。

[RELY]

`kern/process/proc.h` 定义了 `struct proc_struct`、`struct context` 和进程状态。`context` 保存 `ra`、`sp`、`s0` 至 `s11`。`pgdir` 保存页表根的物理地址，本实验内核线程共享 `boot_pgdir_pa`，其用户地址空间描述符 `mm` 为 `NULL`。

`proc.c` 已有全局链表 `proc_list`、按 PID 索引的 `hash_list`、计数 `nr_process` 及指针 `idleproc`、`initproc`、`current`。普通子线程分别用 `list_link`、`hash_link` 接入两个索引。复用 `get_pid()`、`hash_proc()`、`find_proc()`、`set_proc_name()` 及链表操作。

PCB 由 `kmalloc` 分配，使用 `kfree` 释放。`setup_kstack(proc)` 成功时返回 0，将连续 `KSTACKPAGE` 页的内核虚拟基址写入 `proc->kstack`，失败时返回 `-E_NO_MEM`。`put_kstack(proc)` 回收已分配的栈。启动栈基址为 `bootstack`。

`kern/trap/trap.h` 的 `struct trapframe` 含 `gpr`、`status` 和 `epc` 等字段。`forkret()` 已调用 `forkrets(current->tf)`，后者通过 Trap 返回路径恢复中断帧。`kernel_thread_entry` 的汇编约定是把 `s1` 移至 `a0`，经 `s0` 调用线程函数，再将返回值交给 `do_exit`。

`kern/mm/pmm.h` 提供 `CLONE_VM`，`libs/riscv.h` 提供 `read_csr(sstatus)` 及 `SSTATUS_SPP`、`SSTATUS_SPIE`、`SSTATUS_SIE`。`local_intr_save` 与 `local_intr_restore` 成对使用，可恢复调用前的中断状态。已有 `wakeup_proc(proc)` 将尚未就绪的线程置为 `PROC_RUNNABLE`。

[GUARANTEE]

在 `proc.c` 中提供以下定义。前三个为文件内的辅助函数，后三个沿用 `proc.h` 的公开接口。

```c
static struct proc_struct *alloc_proc(void);
static int copy_mm(uint32_t clone_flags, struct proc_struct *proc);
static void copy_thread(struct proc_struct *proc, uintptr_t stack, struct trapframe *tf);
int do_fork(uint32_t clone_flags, uintptr_t stack, struct trapframe *tf);
int kernel_thread(int (*fn)(void *), void *arg, uint32_t clone_flags);
void proc_init(void);
```

[SPECIFICATION]

## alloc_proc

**Pre-Condition**　内核堆已初始化。新分配的 PCB 内存可能含有旧数据。

**Post-Condition**

- **分配成功**　返回尚未登记的 PCB。初值为 `state = PROC_UNINIT`、`pid = -1`、`pgdir = boot_pgdir_pa`。`runs`、`kstack`、`need_resched`、`flags` 均为零，`parent`、`mm`、`tf` 均为空，整个 `context` 和名称缓冲区清零。链表节点尚未挂入全局索引，进程总数保持原值。
- **分配失败**　返回 `NULL`，不产生登记记录。

## copy_mm

**Pre-Condition**　`current` 是内核线程，`proc` 指向刚分配的子 PCB。

**Post-Condition**　明确检查本实验仅支持的前提 `current->mm == NULL`。该前提成立时返回 0，子线程的 `mm` 为空，`pgdir` 指向共享的内核页表。此阶段无须分配、复制或释放用户页表。

## copy_thread

**Pre-Condition**　子线程已获得独立内核栈，`tf` 指向可读的完整模板。参数 `stack` 为零，或给出调用方指定的恢复栈指针。

**Post-Condition**　在子线程内核栈高端为一份完整中断帧预留空间，其首地址为 `proc->kstack + KSTACKSIZE - sizeof(struct trapframe)`。将模板复制到这里，令 `proc->tf` 指向副本。仅在副本中将 `gpr.a0` 设为 0，并设置 `gpr.sp`。保留模板中的线程函数、参数、入口和状态字。

**默认栈**　当 `stack == 0` 时，副本的 `gpr.sp` 指向该帧首地址，使向低地址增长的执行栈有可用空间。

**显式栈**　当 `stack != 0` 时，副本的 `gpr.sp` 取该参数值。两种情况下，首次上下文切换使用的 `context.sp` 均指向子线程自己的中断帧，`context.ra` 均指向 `forkret`。

## do_fork

**Pre-Condition**　`current` 有效，全局进程索引已初始化，`tf` 在本次调用期间有效。

**Post-Condition**

- **达到容量上限**　若 `nr_process >= MAX_PROCESS`，返回 `-E_NO_FREE_PROC`，不申请资源。
- **创建成功**　分配 PCB，记录父线程为 `current`，分配独立内核栈，再完成地址空间处理和执行现场复制。准备就绪后，分配唯一的正 PID，将子线程在 PID 哈希表和进程链表各登记一次，进程计数加一，再通过 `wakeup_proc` 使其就绪。父线程得到子 PID，此时能用 `find_proc(pid)` 找到同一 PCB，`current` 仍指向父线程。
- **创建失败**　PCB 分配失败返回 `-E_NO_MEM`。栈分配失败时只释放 PCB。地址空间处理若返回错误，则先回收已取得的栈，再释放 PCB，并传回相应负错误码。任何失败路径都应保持两个全局索引及计数与调用前一致。

**Requirements**　用保存和恢复本地中断状态的临界区保护 PID 分配、两个索引的登记和计数更新，让调度器只能选到现场完整且已登记的就绪线程。

## kernel_thread

**Pre-Condition**　`fn` 是有效的内核线程入口，`arg` 为原样传入的参数，可为空。

**Post-Condition**　从清零的局部中断帧构造启动现场。`gpr.s0` 保存 `fn`，`gpr.s1` 保存 `arg`，`epc` 指向 `kernel_thread_entry`。从当前 `sstatus` 派生帧中的 `status`，设置 `SPP` 和 `SPIE`，清除 `SIE`，保留其余位，使首次 `sret` 返回监管态并启用中断。用 `clone_flags | CLONE_VM`、零栈参数和该帧调用 `do_fork`，原样返回 PID 或负错误码。创建者返回后，子线程的现场仍然有效。

## proc_init

**Pre-Condition**　`kern_init()` 已完成内存管理初始化，当前正在启动栈上执行，进程子系统首次初始化。

**Post-Condition**

**建立 idle**　初始化进程链表表头及所有哈希桶。用 `alloc_proc()` 分配 `idleproc`，赋 PID 0，命名为 `idle`，复用 `bootstack`，状态设为 `PROC_RUNNABLE`，`need_resched` 置位。使 `current == idleproc` 并把 idle 计入进程总数。idle 单独由 `idleproc` 持有，供调度器兜底。其 `parent`、`mm`、`tf` 为空，`runs`、`flags` 和初始上下文为零。

**建立 init**　以 idle 为父线程，通过 `kernel_thread(init_main, "Hello world!!", 0)` 创建第一个普通内核线程。用返回的 PID 查得 PCB 后赋给 `initproc`，命名为 `init`。此时 `initproc->pid == 1`、`initproc->parent == idleproc`，其独立内核栈及首次运行现场已就绪。系统共计两个线程，普通进程链表中只有 init。返回调用者，实际切换由后续调度路径负责。

**启动失败**　idle PCB 分配失败、init 创建失败或按成功 PID 找不到 init 时，使用框架的致命错误处理终止初始化，并指出失败阶段。
