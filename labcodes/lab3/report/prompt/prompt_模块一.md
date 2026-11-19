# 功能模块一：Trap 上下文恢复与 Trap 入口功能
**负责人：** 2413115-刘卓明

[PROMPT]
**任务**：在 `kern/trap/trapentry.S` 的两处 `#lab3 function1 YOUR CODE` 标记下实现 Trap 入口和上下文恢复功能。

- `RESTORE_ALL`：从当前 `sp` 指向的 Trap frame 中恢复用户程序的寄存器值，以及用于 Trap 返回的 `sstatus` 和 `sepc`，使被打断程序的执行状态能够从 Trap frame 中恢复出来。
- `__alltraps`：建立汇编 Trap 入口与 `trap(struct trapframe *tf)` 之间的调用关系。使保存后的 Trap frame 能够按照 RISC-V 调用约定正确传递给 trap()。

**操作要求**：必须在项目中修改实际文件，而不是仅展示代码。仅在 `RESTORE_ALL` 宏体内和 `__alltraps` 的两处 `#lab3 function1 YOUR CODE` 标记下补全模块。保留 `__alltraps`、`__trapret`已有的代码，不要删除既有逻辑。

**输出要求**：直接在标记位置写入完整实现，保留文件中现有代码与测试函数
使用下列 [RELY]、[GUARANTEE] 和 [SPECIFICATION] 中的信息，以工程真实代码为准，不要引入无关功能。模块完成后，系统应能够形成完整的“Trap 进入 -> 上下文保存 -> C 语言处理 -> 上下文恢复 -> Trap 返回”闭环


[RELY]

**Trap frame 布局与 C 层处理接口**（`kern/trap/trap.h`，`kern/trap/trap.c`）

```c
struct trapframe {
    struct pushregs gpr;
    uintptr_t status;
    uintptr_t epc;
    uintptr_t badvaddr;
    uintptr_t cause;
};

void trap(struct trapframe *tf);
```

**已有上下文保存宏 `SAVE_ALL`**（`kern/trap/trapentry.S`）

```asm
    .macro SAVE_ALL

    csrw sscratch, sp

    addi sp, sp, -36 * REGBYTES
    # 此处省略 x0、x1 和 x3–x31 的保存指令
    csrrw s0, sscratch, x0
    csrr s1, sstatus
    csrr s2, sepc
    csrr s3, sbadaddr
    csrr s4, scause

    STORE s0, 2*REGBYTES(sp)
    STORE s1, 32*REGBYTES(sp)
    STORE s2, 33*REGBYTES(sp)
    STORE s3, 34*REGBYTES(sp)
    STORE s4, 35*REGBYTES(sp)
    .endm
```

**汇编入口、恢复宏与返回路径**（`kern/trap/trapentry.S`）

```asm
    .macro RESTORE_ALL

    #lab3 function1 YOUR CODE

    .endm

    .globl __alltraps
    .align(2)
__alltraps:
    SAVE_ALL

    #lab3 function1 YOUR CODE
    # sp should be the same as before "jal trap"

    .globl __trapret
__trapret:
    RESTORE_ALL
    # return from supervisor call
    sret
```

**RISC-V 函数调用约定与特权级返回**

- 调用 `trap()` 时，首个指针参数通过 `a0` 传递，栈指针须满足调用约定的对齐要求。
- `sret` 从 `sepc` 取得返回地址，根据 `sstatus.SPP` 恢复返回特权级，并将 `sstatus.SPIE` 的值转入 `sstatus.SIE`。


[GUARANTEE]
必须补全的汇编接口：

```asm
.macro RESTORE_ALL
__alltraps:
```

- `RESTORE_ALL` 从当前 Trap frame 恢复通用寄存器和 Trap 返回状态。
- `__alltraps` 通过已有的 `SAVE_ALL` 建立 Trap frame，将帧地址传给 `trap()`，并在 C 函数正常返回后接入现有 `__trapret`。

你可以根据需要添加：
本模块内部使用的 `static` 辅助函数。
模块内部使用的`static`变量

[SPECIFICATION]
## RESTORE_ALL

**Pre-Condition**：`sp` 指向由 `SAVE_ALL` 建立且经过 `trap()` 处理的有效 Trap frame。

**Post-Condition**：按帧中的当前值恢复需保留的通用寄存器及 Trap 返回所需的 CSR，包括 `sstatus` 和 `sepc` 。`sp` 恢复为帧中保存的原用户程序的栈指针，由已有的 `sret` 完成返回。

**Requirements**：读取帧时，`RESTORE_ALL`必须与 `SAVE_ALL` 一致，不能自行假设一个与实际 Trap frame 不一致的数据布局。

## __alltraps

**Pre-Condition**：处理器已进入 Trap，入口栈和处理器状态满足现有 `SAVE_ALL` 的使用条件。

**Post-Condition**：`trap()` 收到指向本次 Trap frame 的 `struct trapframe *`。`trap()` 正常返回后，控制流进入现有 `__trapret`，此时 `sp` 指向同一个 Trap frame。

**Requirements**：进入 `__trapret` 前，`sp` 必须重新指向本次 Trap frame。
