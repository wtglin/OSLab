[PROMPT]

**任务**　在 `lab3/lab3_new/` 工程中实现功能模块二中断与异常处理，唯一目标文件是 `kern/trap/trap.c`。在 `//lab3 function2 YOUR CODE` 标记处、已有 `trap_dispatch()` 之前补全两个处理函数，使内核能持续响应时钟中断，并能在处理非法指令和断点后从下一条指令继续执行。

**操作要求**　执行此提示词时必须修改工程中的实际文件。保留实验标记注释，提交时用本人学号替换 `YOUR CODE`。本次只补全模块二，允许在目标文件中引用 `<sbi.h>`、定义必要的模块私有常量或静态辅助函数。保留已有函数、头文件接口、模块一的汇编和评分程序。Lab2 的物理内存管理代码作为前置依赖使用。

**输出要求**　按下列三个部分实现。完成后列出修改文件，简述时钟重设、统计与关机的先后关系，以及中断和两种已处理异常各自如何决定返回地址。无需编译、运行或评分。

[RELY]

- `kern/trap/trap.h` 中的 `struct trapframe` 包含 `uintptr_t cause`、`uintptr_t epc` 及保存的寄存器。`trap_dispatch()` 根据 `(intptr_t)tf->cause < 0` 将中断与同步异常分别交给两个处理函数。RV64 的中断标志占 `cause` 的最高位，其余位给出原因号。返回路径从同一 Trap frame 恢复 `sepc`。
- `libs/riscv.h` 定义了各特权级的软件、时钟和外部中断编号，其中 `IRQ_S_TIMER` 为 5。`CAUSE_ILLEGAL_INSTRUCTION` 为 2，`CAUSE_BREAKPOINT` 为 3。
- `kern/driver/clock.h` 提供 `extern volatile size_t ticks` 和 `void clock_set_next_event(void)`。`clock_init()` 已将计数置零并安排首次事件。后续事件需要处理函数逐次安排。
- `trap.c` 已定义 `TICK_NUM` 为 100。`print_ticks()` 输出一行 `100 ticks`，并有自己的 `DEBUG_GRADE` 分支。复用该函数并保留原有调试行为。`print_trapframe(tf)` 可输出完整现场，`libs/sbi.h` 声明了 `void sbi_shutdown(void)`。
- 实验内容用 `SHUTDOWN_AFTER` 表示关机前累计输出的行数，当前材料未给出数值，源码也未定义该宏。若构建时已指定该宏，使用指定值；否则在目标文件中给出可覆盖的默认值 10，并在修改说明中标明这一实现假设。
- `tools/grade.sh` 给出了诊断文本的大小写。`tools/test_lab3.c` 中的非法指令为 4 字节的 `.word 0x0000007b`；`tools/test_lab3_context.S` 中的 `ebreak` 后面紧接寄存器检查，须按其实际机器编码长度返回。

[GUARANTEE]

在标记处提供以下两个函数定义，保持外部链接，使现有分发函数和直接调用它们的测试都能使用同一接口。

```c
void interrupt_handler(struct trapframe *tf);
void exception_handler(struct trapframe *tf);
```

[SPECIFICATION]

## interrupt_handler

**Pre-Condition**　`tf` 指向有效的 Trap frame。正常分发携带中断标志，现有测试也会直接传入不带标志的未知原因号 15。时钟中断路径以已初始化的时钟驱动为前提。

**Post-Condition**　按去除最高标志位后的原因号完成分类，同时保留 `tf->cause` 原值供诊断。所有返回分支保持 `tf->epc`、通用寄存器和状态字原值，使被打断的执行流从保存位置恢复。

- **Case 1 · 监管态时钟中断**　每次收到 `IRQ_S_TIMER`，先设置下一次时钟事件，再将全局 `ticks` 加一。当新计数为 `TICK_NUM` 的正整数倍时，调用一次 `print_ticks()`。例如第 99 次无统计行，第 100 次和第 200 次各输出一行 `100 ticks`。统计行数达到 `SHUTDOWN_AFTER` 时，先完成最后一行输出，再调用 `sbi_shutdown()`；此前应正常返回。
- **Case 2 · 其他已识别中断**　按框架中相应的 IRQ 常量区分软件、其他特权级的时钟及外部中断，输出包含特权级和类型的提示。特别地，`IRQ_S_SOFT` 输出一行 `Supervisor software interrupt`。这些分支保持定时器、`ticks` 和统计次数原值。
- **Case 3 · 未识别中断**　输出 `Unknown interrupt: cause <十进制原因号>`，随后调用一次 `print_trapframe(tf)`。直接传入 15 时首行应为 `Unknown interrupt: cause 15`，且能正常返回。

**Requirements**　复用驱动维护的唯一 `ticks`。统计与关机取决于实际收到的监管态时钟中断次数；正常路径下，最终统计行只输出一次。中断处理不推进指令地址。

## exception_handler

**Pre-Condition**　`tf` 指向有效的同步异常现场。非法指令与断点场景中，`tf->epc` 指向实验内核中可读取的故障指令，可能仅按 2 字节对齐。其他异常的兜底路径无需读取该地址。

**Post-Condition**　对已处理的两类异常，先报告触发地址，再仅更新 `tf->epc` 到紧随故障指令的地址。保持其他现场字段、时钟与统计状态原值，由统一的 Trap 返回路径恢复执行。

- **Case 1 · 非法指令**　遇到 `CAUSE_ILLEGAL_INSTRUCTION`，输出一行 `Illegal instruction at <原 epc 的十六进制地址>`。对于工程中的 `.word 0x0000007b`，返回地址应为原地址加 4。
- **Case 2 · 断点**　遇到 `CAUSE_BREAKPOINT`，输出一行 `Breakpoint at <原 epc 的十六进制地址>`。压缩编码 `c.ebreak` 后前进 2 字节，普通 32 位编码 `ebreak` 后前进 4 字节。两者都应恰好落到断点后的第一条指令。
- **Case 3 · 其他异常**　调用一次 `print_trapframe(tf)`，保留原始异常现场后返回。例如直接传入原因号 20 时，即使 `epc` 为零也应能输出现场，包含框架已有的 `cause    0x00000014` 行。

**Requirements**　对本实验涉及的 16 位和 32 位编码，依据故障地址处首个 16 位半字的低两位判定长度：低两位非二进制 `11` 表示 2 字节，本实验的 32 位编码低两位为 `11`。仅在上述两个已处理分支读取指令。输出地址时保留 RV64 地址宽度；通过 Trap frame 传回更新后的执行位置。
