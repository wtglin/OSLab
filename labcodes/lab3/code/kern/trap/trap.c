#include <assert.h>
#include <clock.h>
#include <console.h>
#include <defs.h>
#include <kdebug.h>
#include <memlayout.h>
#include <mmu.h>
#include <riscv.h>
#include <sbi.h>
#include <stdio.h>
#include <trap.h>

#define TICK_NUM 100

static void print_ticks() {
    cprintf("%d ticks\n", TICK_NUM);
#ifdef DEBUG_GRADE
    cprintf("End of Test.\n");
    panic("EOT: kernel seems ok.");
#endif
}

/* idt_init - initialize IDT to each of the entry points in kern/trap/vectors.S
 */
void idt_init(void) {

    extern void __alltraps(void);
    /* Set sup0 scratch register to 0, indicating to exception vector
       that we are presently executing in the kernel */
    write_csr(sscratch, 0);
    /* Set the exception vector address */
    write_csr(stvec, &__alltraps);
}

/* trap_in_kernel - test if trap happened in kernel */
bool trap_in_kernel(struct trapframe *tf) {
    return (tf->status & SSTATUS_SPP) != 0;
}

void print_trapframe(struct trapframe *tf) {
    cprintf("trapframe at %p\n", tf);
    print_regs(&tf->gpr);
    cprintf("  status   0x%08x\n", tf->status);
    cprintf("  epc      0x%08x\n", tf->epc);
    cprintf("  badvaddr 0x%08x\n", tf->badvaddr);
    cprintf("  cause    0x%08x\n", tf->cause);
}

void print_regs(struct pushregs *gpr) {
    cprintf("  zero     0x%08x\n", gpr->zero);
    cprintf("  ra       0x%08x\n", gpr->ra);
    cprintf("  sp       0x%08x\n", gpr->sp);
    cprintf("  gp       0x%08x\n", gpr->gp);
    cprintf("  tp       0x%08x\n", gpr->tp);
    cprintf("  t0       0x%08x\n", gpr->t0);
    cprintf("  t1       0x%08x\n", gpr->t1);
    cprintf("  t2       0x%08x\n", gpr->t2);
    cprintf("  s0       0x%08x\n", gpr->s0);
    cprintf("  s1       0x%08x\n", gpr->s1);
    cprintf("  a0       0x%08x\n", gpr->a0);
    cprintf("  a1       0x%08x\n", gpr->a1);
    cprintf("  a2       0x%08x\n", gpr->a2);
    cprintf("  a3       0x%08x\n", gpr->a3);
    cprintf("  a4       0x%08x\n", gpr->a4);
    cprintf("  a5       0x%08x\n", gpr->a5);
    cprintf("  a6       0x%08x\n", gpr->a6);
    cprintf("  a7       0x%08x\n", gpr->a7);
    cprintf("  s2       0x%08x\n", gpr->s2);
    cprintf("  s3       0x%08x\n", gpr->s3);
    cprintf("  s4       0x%08x\n", gpr->s4);
    cprintf("  s5       0x%08x\n", gpr->s5);
    cprintf("  s6       0x%08x\n", gpr->s6);
    cprintf("  s7       0x%08x\n", gpr->s7);
    cprintf("  s8       0x%08x\n", gpr->s8);
    cprintf("  s9       0x%08x\n", gpr->s9);
    cprintf("  s10      0x%08x\n", gpr->s10);
    cprintf("  s11      0x%08x\n", gpr->s11);
    cprintf("  t3       0x%08x\n", gpr->t3);
    cprintf("  t4       0x%08x\n", gpr->t4);
    cprintf("  t5       0x%08x\n", gpr->t5);
    cprintf("  t6       0x%08x\n", gpr->t6);
}

//lab3 function2 2411153
#ifndef SHUTDOWN_AFTER
#define SHUTDOWN_AFTER 10
#endif

void interrupt_handler(struct trapframe *tf) {
    const uintptr_t interrupt_bit = (uintptr_t)1 << 63;
    uintptr_t cause = tf->cause & ~interrupt_bit;

    if (cause == IRQ_S_TIMER) {
        clock_set_next_event();
        size_t count = ++ticks;
        if (count % TICK_NUM == 0) {
            print_ticks();
            if (count / TICK_NUM == SHUTDOWN_AFTER) {
                sbi_shutdown();
            }
        }
        return;
    }

    static const char *const messages[] = {
        [IRQ_U_SOFT]  = "User software interrupt",
        [IRQ_S_SOFT]  = "Supervisor software interrupt",
        [IRQ_H_SOFT]  = "Hypervisor software interrupt",
        [IRQ_M_SOFT]  = "Machine software interrupt",
        [IRQ_U_TIMER] = "User timer interrupt",
        [IRQ_H_TIMER] = "Hypervisor timer interrupt",
        [IRQ_M_TIMER] = "Machine timer interrupt",
        [IRQ_U_EXT]   = "User external interrupt",
        [IRQ_S_EXT]   = "Supervisor external interrupt",
        [IRQ_H_EXT]   = "Hypervisor external interrupt",
        [IRQ_M_EXT]   = "Machine external interrupt",
        [IRQ_COP]     = "Coprocessor interrupt",
        [IRQ_HOST]    = "Host interrupt",
    };
    if (cause < sizeof(messages) / sizeof(messages[0]) && messages[cause]) {
        cprintf("%s\n", messages[cause]);
        return;
    }
    cprintf("Unknown interrupt: cause %lu\n", (unsigned long)cause);
    print_trapframe(tf);
}

void exception_handler(struct trapframe *tf) {
    switch (tf->cause) {
    case CAUSE_ILLEGAL_INSTRUCTION:
        cprintf("Illegal instruction at %p\n", (void *)tf->epc);
        break;
    case CAUSE_BREAKPOINT:
        cprintf("Breakpoint at %p\n", (void *)tf->epc);
        break;
    default:
        print_trapframe(tf);
        return;
    }

    // Both instruction widths used in the lab start on a halfword boundary.
    uint16_t first_halfword = *(const volatile uint16_t *)tf->epc;
    tf->epc += (first_halfword & 3) == 3 ? 4 : 2;
}

static inline void trap_dispatch(struct trapframe *tf) {
    if ((intptr_t)tf->cause < 0) {
        // interrupts
        interrupt_handler(tf);
    } else {
        // exceptions
        exception_handler(tf);
    }
}

/* *
 * trap - handles or dispatches an exception/interrupt. if and when trap()
 * returns,
 * the code in kern/trap/trapentry.S restores the old CPU state saved in the
 * trapframe and then uses the iret instruction to return from the exception.
 * */
void trap(struct trapframe *tf) {
    // dispatch based on what type of trap occurred
    trap_dispatch(tf);
}
