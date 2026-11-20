[PROMPT]

**任务**：在 `kern/schedule/sched.c` 的 `//LAB4 function3 2411248` 处实现 `schedule()`；在 `kern/process/proc.c` 末尾的同一标记处实现 `proc_run()` 与 `cpu_idle()`；在 `kern/process/switch.S` 中实现 `switch_to()`。三者共同完成“选择下一个可运行进程 → 更新 `current` 与内核栈 → 保存当前上下文、恢复目标上下文 → 新进程从自己的返回地址继续执行”的调度闭环。

**操作要求**：必须修改项目中的实际文件，而不是只展示代码。只允许在上述三个文件的指定标记或现有空文件内补全实现；保留 `wakeup_proc()`、`alloc_proc()`、`do_fork()`、`proc_init()`、`kernel_thread()`、`copy_thread()` 等已有函数及注释，不要删除或改写既有逻辑。不得修改 `proc.h`、`sched.h`、`tools/test_lab4.c`、`tools/inject.py`、`tools/grade.sh`、`Makefile`、`CMakeLists.txt`；不得改动 `trap.c`、`trapentry.S` 等 lab3 代码；不得实现 lab5 的 `do_exit()` 或用户进程功能。保留 `LAB4 function3` 标记，并将 `YOUR CODE` 替换为学号 `2411248`。

**输出要求**：直接在文件中写入完整实现，保证 `make` 能编译、`make grade` 能运行；调度测试应输出 `[Test Schedule] PASS`，并保留 `this initproc, pid = 1, name = "init"` 等既有输出。使用下面 `[RELY]`、`[GUARANTEE]`、`[SPECIFICATION]` 中的信息，以工程真实代码为准；模块完成后不得破坏 `[Test PMM] PASS` 与 `[Test Process Create] PASS`。

[RELY]

**进程控制块与上下文布局**（`kern/process/proc.h`）

```c
struct context {
    uintptr_t ra;      // 偏移 0
    uintptr_t sp;      // 偏移 1
    uintptr_t s0;      // 偏移 2
    uintptr_t s1;      // 偏移 3
    uintptr_t s2;      // 偏移 4
    uintptr_t s3;      // 偏移 5
    uintptr_t s4;      // 偏移 6
    uintptr_t s5;      // 偏移 7
    uintptr_t s6;      // 偏移 8
    uintptr_t s7;      // 偏移 9
    uintptr_t s8;      // 偏移 10
    uintptr_t s9;      // 偏移 11
    uintptr_t s10;     // 偏移 12
    uintptr_t s11;     // 偏移 13
};

struct proc_struct {
    enum proc_state state;
    int pid;
    int runs;
    uintptr_t kstack;
    volatile bool need_resched;
    struct proc_struct *parent;
    struct mm_struct *mm;
    struct context context;
    struct trapframe *tf;
    uintptr_t pgdir;
    uint32_t flags;
    char name[PROC_NAME_LEN + 1];
    list_entry_t list_link;
    list_entry_t hash_link;
};

extern list_entry_t proc_list;
extern struct proc_struct *idleproc, *initproc, *current;
```

**进程队列与链表接口**（`libs/list.h`）

`proc_list` 是带哨兵头的双向循环链表；`list_next(&proc_list)` 取首元素；`le2proc(le, list_link)` 由链表节点取回 PCB。`idleproc` 由 `proc_init()` 单独创建，不会插入 `proc_list`；`initproc` 和 `kernel_thread()` 创建的线程由 `do_fork()` 通过 `list_add(&proc_list, &proc->list_link)` 插入。因此扫描时不能假设 `idleproc` 在队列中，也不能对哨兵头 `&proc_list` 调用 `le2proc`。

**已有函数与初始状态**

- `wakeup_proc(proc)` 已实现，只把 `proc->state` 置为 `PROC_RUNNABLE`；
- `proc_init()` 已设置 `idleproc->state = PROC_RUNNABLE`、`idleproc->need_resched = 1`、`idleproc->kstack = (uintptr_t)bootstack`、`current = idleproc`；
- `kernel_thread()` → `do_fork()` → `copy_thread()` 已为新线程建立 `tf`、`context.ra = forkret`、`context.sp = tf`；`forkret()` 会调用 `forkrets(current->tf)` 进入 `__trapret`；
- `switch_to()` 在 `proc.c` 中已有声明：`void switch_to(struct context *from, struct context *to);`
- `proc_run()`、`cpu_idle()` 在 `proc.h` 中已有声明，`schedule()` 在 `sched.h` 中已有声明。

**中断、内核栈与 CSR**

- `sync.h` 提供 `local_intr_save(intr_flag)` / `local_intr_restore(intr_flag)`；
- `memlayout.h`：`KSTACKPAGE = 2`，`KSTACKSIZE = KSTACKPAGE * PGSIZE`；`proc->kstack` 是内核栈低地址，栈顶为 `proc->kstack + KSTACKSIZE`；
- `idleproc` 的栈是 `kern/init/entry.S` 中的 `bootstack`，栈顶为 `bootstacktop`；
- `riscv.h` 提供 `write_csr(sscratch, val)`、`STORE`、`LOAD`、`REGBYTES`；`switch.S` 需要包含 `<riscv.h>`。

**地址空间**

`copy_mm()` 把 `proc->pgdir` 统一设为 `boot_pgdir_pa`，本实验所有内核线程共享内核页表；模块三不需要切换 `satp`，也不要调用 32 位专用的 `lsatp()`。

**测试行为**（`tools/test_lab4.c`，评分时由 `tools/inject.py` 注入到 `init_main()` 开头）

- `test_lab4_schedule()` 先通过 `kernel_thread()` 创建两个 `test_lab4_thread` 线程；
- 两个线程各自循环 3 次，每次置 `current->need_resched = 1` 后调用 `schedule()`，之后进入无限让出循环；
- 测试主体（`initproc`）也循环 8 次，置 `need_resched = 1` 并调用 `schedule()`；
- 最后断言两个线程都运行过，打印 `[Test Schedule] PASS`；
- `tools/grade.sh` 还要求输出 `this initproc, pid = 1, name = "init"`、`To U: "Hello world!!".`、`To U: "en.., Bye, Bye. :)"`。

**构建**：`Makefile` 的 `CTYPE := c S`，`KSRCDIR` 包含 `kern/process`，`kern/process/switch.S` 会被自动编译；不需要修改 `Makefile` 或 `CMakeLists.txt`。

[GUARANTEE]

必须实现以下四个函数/符号，签名不可改：

```c
/* kern/schedule/sched.c */
void schedule(void);

/* kern/process/proc.c */
void proc_run(struct proc_struct *proc);
void cpu_idle(void);

/* kern/process/switch.S */
void switch_to(struct context *from, struct context *to);
```

- `schedule()` 写在 `sched.c` 的 `//LAB4 function3 2411248` 处，保留 `wakeup_proc()` 原样；
- `proc_run()`、`cpu_idle()` 写在 `proc.c` 末尾的同一标记处，保留 `alloc_proc()`、`do_fork()`、`proc_init()` 等已有实现；
- `switch_to()` 写在 `switch.S`，必须有 `.text` 与 `.globl switch_to`；当前文件只有一行标记，可直接替换为完整汇编；
- `switch_to` 的偏移必须与 `struct context` 一致：`ra=0`、`sp=1`、`s0=2`、…、`s11=13`，单位 `REGBYTES`；
- 可以增加模块内部 `static` 辅助函数/变量，但不得新增跨文件接口，不得改动 `proc.h`、`sched.h` 的已有声明；
- 不得修改 `tools/test_lab4.c`、`tools/inject.py`、`tools/grade.sh`、`Makefile`、`CMakeLists.txt`；
- 不得修改 `kern/trap/trap.c`、`kern/trap/trapentry.S` 等 lab3 代码，也不得实现 lab5 的 `do_exit()`/用户进程功能；
- 完成后必须同时保持 `[Test PMM] PASS`、`[Test Process Create] PASS`、`[Test Schedule] PASS`。

[SPECIFICATION]

## switch_to

**Pre-Condition**：`from`、`to` 均指向有效的 `struct context`；调用发生在内核态，`sp` 指向当前内核栈；调用者已关闭中断。

**Post-Condition**：`from` 中依次保存调用点的 `ra`、`sp`、`s0`–`s11`；从 `to` 中恢复同样 14 个值；执行 `ret` 后，控制流跳到 `to->ra`，栈指针为 `to->sp`，`s0`–`s11` 为 `to` 中的值。

**Requirements**：
- 必须使用 `<riscv.h>` 提供的 `STORE`、`LOAD`、`REGBYTES`，不能硬编码 8 字节偏移；
- 保存/恢复顺序必须与 `struct context` 完全一致：`ra` 0、`sp` 1、`s0` 2、`s1` 3、…、`s11` 13；
- 只能把 `a0`、`a1` 作为 `from`/`to` 指针；不要用 `s0`–`s11` 做临时寄存器；
- 不需要保存/恢复 `a0`、`a1`、`t0`–`t6`；不要写 C 函数序言/尾声，也不要在 `switch_to` 内调用其它函数；
- 最后一条指令必须是 `ret`，由恢复出的 `to->ra` 决定返回位置。

**Case 1（切换到已运行过的线程）**：`to->ra` 是 `to` 上次调用 `switch_to` 时的返回地址；`ret` 后它从该点继续，`proc_run()` 随后恢复中断并返回。

**Case 2（首次切换到新线程）**：`to->ra = forkret`、`to->sp = tf`；`ret` 后执行 `forkret()`，它用 `current->tf` 调用 `forkrets()`，再进入 `__trapret` 恢复新线程的 Trap frame。

## proc_run

**Pre-Condition**：`proc != NULL`，`proc->state == PROC_RUNNABLE`；`current` 指向当前进程；中断可以已开启或已关闭。

**Post-Condition**：若 `proc == current`，立即返回，不切换；否则在关中断临界区内把 `current` 改为 `proc`，把 `sscratch` 设为 `proc->kstack + KSTACKSIZE`，调用 `switch_to(&prev->context, &proc->context)`；当本进程以后再次被调度时，`switch_to` 返回到此处，恢复调用前的中断状态。

**Requirements**：
- 必须在修改 `current` 前保存 `prev = current`，并把目标保存在局部变量 `next` 中；
- `write_csr(sscratch, ...)` 必须在 `switch_to` 之前执行；
- 使用 `local_intr_save(intr_flag)` / `local_intr_restore(intr_flag)` 包住 `current` 更新与 `switch_to`；
- `switch_to` 返回后不要再写 `current = proc`：返回发生在该进程被重新调度时，参数 `proc` 可能已不是当前进程；
- 不切换页表，不清 `need_resched`，不操作 `proc_list`；
- 不要在 `proc_run` 内调用 `schedule()`。

**Case 1（`proc == current`）**：直接返回。
**Case 2（`proc != current`）**：关中断，更新 `current` 和 `sscratch`，调用 `switch_to`；本进程恢复后开中断并返回。

## schedule

**Pre-Condition**：`current` 有效；`proc_list` 已由 `proc_init()` 初始化；调用者可以是 `idleproc`、`initproc` 或任一内核线程；中断可以已开启。

**Post-Condition**：`current->need_resched` 被清零；从 `proc_list` 中按环形顺序选出下一个 `PROC_RUNNABLE` 进程 `next`；`next->runs` 加一；若 `next != current`，调用 `proc_run(next)` 完成切换；函数返回时，`current` 指向本进程，中断状态恢复。

**Requirements**：
- 必须在关中断临界区内完成“扫描 + 选择 + `proc_run` 调用”，返回前恢复中断；
- 扫描起点：`current == idleproc` 时从 `&proc_list` 开始，否则从 `&current->list_link` 开始；
- 用 `list_next()` 环形前进，遇到哨兵头 `&proc_list` 跳过，不能对头节点调用 `le2proc`；
- 只选择 `state == PROC_RUNNABLE` 的进程；`PROC_UNINIT`、`PROC_SLEEPING`、`PROC_ZOMBIE` 一律跳过；
- 第一轮扫描跳过 `current` 自身；若没有其它可运行进程，再检查 `current` 是否仍为 `PROC_RUNNABLE`，是则选 `current`；否则选 `idleproc`；
- `idleproc` 不在 `proc_list` 中，必须作为兜底单独处理；`proc_list` 为空时直接选 `idleproc`；
- 不得在扫描中修改任何进程的 `state`，不得调用 `wakeup_proc()`、`do_exit()` 或睡眠；
- 选中后执行 `next->runs++`；若 `next == current`，不调用 `proc_run`，直接恢复中断并返回；
- 不要递归调用 `schedule()`。

**Case 1（存在其它 RUNNABLE）**：选扫描到的第一个，切换。
**Case 2（只有 current 为 RUNNABLE）**：选 current，`runs++`，不切换。
**Case 3（没有 RUNNABLE）**：选 `idleproc`；若 `current == idleproc`，不切换。
**Case 4（`proc_list` 为空）**：选 `idleproc`。

## cpu_idle

**Pre-Condition**：`current == idleproc`，在 `kern_init()` 末尾被调用。

**Post-Condition**：永不返回；循环把 `current->need_resched` 置 1 并调用 `schedule()`；没有可运行进程时，`schedule()` 选回 `idleproc`，循环继续。

**Requirements**：
- 必须是无限循环，不能返回；
- 每轮必须调用 `schedule()`，不能只忙等；
- 不调用 `panic()`，不修改 `idleproc` 之外的状态。