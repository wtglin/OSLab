
bin/kernel:     file format elf64-littleriscv


Disassembly of section .text:

ffffffffc0200000 <kern_entry>:
    .globl kern_entry
kern_entry:
    # a0: hartid
    # a1: dtb physical address
    # save hartid and dtb address
    la t0, boot_hartid
ffffffffc0200000:	00007297          	auipc	t0,0x7
ffffffffc0200004:	00028293          	mv	t0,t0
    sd a0, 0(t0)
ffffffffc0200008:	00a2b023          	sd	a0,0(t0) # ffffffffc0207000 <boot_hartid>
    la t0, boot_dtb
ffffffffc020000c:	00007297          	auipc	t0,0x7
ffffffffc0200010:	ffc28293          	addi	t0,t0,-4 # ffffffffc0207008 <boot_dtb>
    sd a1, 0(t0)
ffffffffc0200014:	00b2b023          	sd	a1,0(t0)

    # t0 := 三级页表的虚拟地址
    lui     t0, %hi(boot_page_table_sv39)
ffffffffc0200018:	c02062b7          	lui	t0,0xc0206
    # t1 := 0xffffffff40000000 即虚实映射偏移量
    li      t1, 0xffffffffc0000000 - 0x80000000
ffffffffc020001c:	ffd0031b          	addiw	t1,zero,-3
ffffffffc0200020:	037a                	slli	t1,t1,0x1e
    # t0 减去虚实映射偏移量 0xffffffff40000000，变为三级页表的物理地址
    sub     t0, t0, t1
ffffffffc0200022:	406282b3          	sub	t0,t0,t1
    # t0 >>= 12，变为三级页表的物理页号
    srli    t0, t0, 12
ffffffffc0200026:	00c2d293          	srli	t0,t0,0xc

    # t1 := 8 << 60，设置 satp 的 MODE 字段为 Sv39
    li      t1, 8 << 60
ffffffffc020002a:	fff0031b          	addiw	t1,zero,-1
ffffffffc020002e:	137e                	slli	t1,t1,0x3f
    # 将刚才计算出的预设三级页表物理页号附加到 satp 中
    or      t0, t0, t1
ffffffffc0200030:	0062e2b3          	or	t0,t0,t1
    # 将算出的 t0(即新的MODE|页表基址物理页号) 覆盖到 satp 中
    csrw    satp, t0
ffffffffc0200034:	18029073          	csrw	satp,t0
    # 使用 sfence.vma 指令刷新 TLB
    sfence.vma
ffffffffc0200038:	12000073          	sfence.vma
    # 从此，我们给内核搭建出了一个完美的虚拟内存空间！
    #nop # 可能映射的位置有些bug。。插入一个nop
    
    # 我们在虚拟内存空间中：随意将 sp 设置为虚拟地址！
    lui sp, %hi(bootstacktop)
ffffffffc020003c:	c0206137          	lui	sp,0xc0206

    # 我们在虚拟内存空间中：随意跳转到虚拟地址！
    # 1. 使用临时寄存器 t1 计算栈顶的精确地址
    lui t1, %hi(bootstacktop)
ffffffffc0200040:	c0206337          	lui	t1,0xc0206
    addi t1, t1, %lo(bootstacktop)
ffffffffc0200044:	00030313          	mv	t1,t1
    # 2. 将精确地址一次性地、安全地传给 sp
    mv sp, t1
ffffffffc0200048:	811a                	mv	sp,t1
    # 现在栈指针已经完美设置，可以安全地调用任何C函数了
    # 然后跳转到 kern_init (不再返回)
    lui t0, %hi(kern_init)
ffffffffc020004a:	c02002b7          	lui	t0,0xc0200
    addi t0, t0, %lo(kern_init)
ffffffffc020004e:	05428293          	addi	t0,t0,84 # ffffffffc0200054 <kern_init>
    jr t0
ffffffffc0200052:	8282                	jr	t0

ffffffffc0200054 <kern_init>:
void grade_backtrace(void);

int kern_init(void) {
    extern char edata[], end[];
    // 先清零 BSS，再读取并保存 DTB 的内存信息，避免被清零覆盖（为了解释变化 正式上传时我觉得应该删去这句话）
    memset(edata, 0, end - edata);
ffffffffc0200054:	00007517          	auipc	a0,0x7
ffffffffc0200058:	fd450513          	addi	a0,a0,-44 # ffffffffc0207028 <free_area>
ffffffffc020005c:	00007617          	auipc	a2,0x7
ffffffffc0200060:	43c60613          	addi	a2,a2,1084 # ffffffffc0207498 <end>
int kern_init(void) {
ffffffffc0200064:	1141                	addi	sp,sp,-16
    memset(edata, 0, end - edata);
ffffffffc0200066:	8e09                	sub	a2,a2,a0
ffffffffc0200068:	4581                	li	a1,0
int kern_init(void) {
ffffffffc020006a:	e406                	sd	ra,8(sp)
    memset(edata, 0, end - edata);
ffffffffc020006c:	753010ef          	jal	ra,ffffffffc0201fbe <memset>
    dtb_init();
ffffffffc0200070:	40e000ef          	jal	ra,ffffffffc020047e <dtb_init>
    cons_init();  // init the console
ffffffffc0200074:	3fc000ef          	jal	ra,ffffffffc0200470 <cons_init>
    const char *message = "(THU.CST) os is loading ...\0";
    //cprintf("%s\n\n", message);
    cputs(message);
ffffffffc0200078:	00002517          	auipc	a0,0x2
ffffffffc020007c:	f5850513          	addi	a0,a0,-168 # ffffffffc0201fd0 <etext>
ffffffffc0200080:	090000ef          	jal	ra,ffffffffc0200110 <cputs>

    print_kerninfo();
ffffffffc0200084:	0dc000ef          	jal	ra,ffffffffc0200160 <print_kerninfo>

    // grade_backtrace();
    idt_init();  // init interrupt descriptor table
ffffffffc0200088:	7b2000ef          	jal	ra,ffffffffc020083a <idt_init>

    pmm_init();  // init physical memory management
ffffffffc020008c:	74e010ef          	jal	ra,ffffffffc02017da <pmm_init>

    idt_init();  // init interrupt descriptor table
ffffffffc0200090:	7aa000ef          	jal	ra,ffffffffc020083a <idt_init>

    clock_init();   // init clock interrupt
ffffffffc0200094:	39a000ef          	jal	ra,ffffffffc020042e <clock_init>
    intr_enable();  // enable irq interrupt
ffffffffc0200098:	796000ef          	jal	ra,ffffffffc020082e <intr_enable>

    /* do nothing */
    while (1)
ffffffffc020009c:	a001                	j	ffffffffc020009c <kern_init+0x48>

ffffffffc020009e <cputch>:
/* *
 * cputch - writes a single character @c to stdout, and it will
 * increace the value of counter pointed by @cnt.
 * */
static void
cputch(int c, int *cnt) {
ffffffffc020009e:	1141                	addi	sp,sp,-16
ffffffffc02000a0:	e022                	sd	s0,0(sp)
ffffffffc02000a2:	e406                	sd	ra,8(sp)
ffffffffc02000a4:	842e                	mv	s0,a1
    cons_putc(c);
ffffffffc02000a6:	3cc000ef          	jal	ra,ffffffffc0200472 <cons_putc>
    (*cnt) ++;
ffffffffc02000aa:	401c                	lw	a5,0(s0)
}
ffffffffc02000ac:	60a2                	ld	ra,8(sp)
    (*cnt) ++;
ffffffffc02000ae:	2785                	addiw	a5,a5,1
ffffffffc02000b0:	c01c                	sw	a5,0(s0)
}
ffffffffc02000b2:	6402                	ld	s0,0(sp)
ffffffffc02000b4:	0141                	addi	sp,sp,16
ffffffffc02000b6:	8082                	ret

ffffffffc02000b8 <vcprintf>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want cprintf() instead.
 * */
int
vcprintf(const char *fmt, va_list ap) {
ffffffffc02000b8:	1101                	addi	sp,sp,-32
ffffffffc02000ba:	862a                	mv	a2,a0
ffffffffc02000bc:	86ae                	mv	a3,a1
    int cnt = 0;
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc02000be:	00000517          	auipc	a0,0x0
ffffffffc02000c2:	fe050513          	addi	a0,a0,-32 # ffffffffc020009e <cputch>
ffffffffc02000c6:	006c                	addi	a1,sp,12
vcprintf(const char *fmt, va_list ap) {
ffffffffc02000c8:	ec06                	sd	ra,24(sp)
    int cnt = 0;
ffffffffc02000ca:	c602                	sw	zero,12(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc02000cc:	1c3010ef          	jal	ra,ffffffffc0201a8e <vprintfmt>
    return cnt;
}
ffffffffc02000d0:	60e2                	ld	ra,24(sp)
ffffffffc02000d2:	4532                	lw	a0,12(sp)
ffffffffc02000d4:	6105                	addi	sp,sp,32
ffffffffc02000d6:	8082                	ret

ffffffffc02000d8 <cprintf>:
 *
 * The return value is the number of characters which would be
 * written to stdout.
 * */
int
cprintf(const char *fmt, ...) {
ffffffffc02000d8:	711d                	addi	sp,sp,-96
    va_list ap;
    int cnt;
    va_start(ap, fmt);
ffffffffc02000da:	02810313          	addi	t1,sp,40 # ffffffffc0206028 <boot_page_table_sv39+0x28>
cprintf(const char *fmt, ...) {
ffffffffc02000de:	8e2a                	mv	t3,a0
ffffffffc02000e0:	f42e                	sd	a1,40(sp)
ffffffffc02000e2:	f832                	sd	a2,48(sp)
ffffffffc02000e4:	fc36                	sd	a3,56(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc02000e6:	00000517          	auipc	a0,0x0
ffffffffc02000ea:	fb850513          	addi	a0,a0,-72 # ffffffffc020009e <cputch>
ffffffffc02000ee:	004c                	addi	a1,sp,4
ffffffffc02000f0:	869a                	mv	a3,t1
ffffffffc02000f2:	8672                	mv	a2,t3
cprintf(const char *fmt, ...) {
ffffffffc02000f4:	ec06                	sd	ra,24(sp)
ffffffffc02000f6:	e0ba                	sd	a4,64(sp)
ffffffffc02000f8:	e4be                	sd	a5,72(sp)
ffffffffc02000fa:	e8c2                	sd	a6,80(sp)
ffffffffc02000fc:	ecc6                	sd	a7,88(sp)
    va_start(ap, fmt);
ffffffffc02000fe:	e41a                	sd	t1,8(sp)
    int cnt = 0;
ffffffffc0200100:	c202                	sw	zero,4(sp)
    vprintfmt((void*)cputch, &cnt, fmt, ap);
ffffffffc0200102:	18d010ef          	jal	ra,ffffffffc0201a8e <vprintfmt>
    cnt = vcprintf(fmt, ap);
    va_end(ap);
    return cnt;
}
ffffffffc0200106:	60e2                	ld	ra,24(sp)
ffffffffc0200108:	4512                	lw	a0,4(sp)
ffffffffc020010a:	6125                	addi	sp,sp,96
ffffffffc020010c:	8082                	ret

ffffffffc020010e <cputchar>:

/* cputchar - writes a single character to stdout */
void
cputchar(int c) {
    cons_putc(c);
ffffffffc020010e:	a695                	j	ffffffffc0200472 <cons_putc>

ffffffffc0200110 <cputs>:
/* *
 * cputs- writes the string pointed by @str to stdout and
 * appends a newline character.
 * */
int
cputs(const char *str) {
ffffffffc0200110:	1101                	addi	sp,sp,-32
ffffffffc0200112:	e822                	sd	s0,16(sp)
ffffffffc0200114:	ec06                	sd	ra,24(sp)
ffffffffc0200116:	e426                	sd	s1,8(sp)
ffffffffc0200118:	842a                	mv	s0,a0
    int cnt = 0;
    char c;
    while ((c = *str ++) != '\0') {
ffffffffc020011a:	00054503          	lbu	a0,0(a0)
ffffffffc020011e:	c51d                	beqz	a0,ffffffffc020014c <cputs+0x3c>
ffffffffc0200120:	0405                	addi	s0,s0,1
ffffffffc0200122:	4485                	li	s1,1
ffffffffc0200124:	9c81                	subw	s1,s1,s0
    cons_putc(c);
ffffffffc0200126:	34c000ef          	jal	ra,ffffffffc0200472 <cons_putc>
    while ((c = *str ++) != '\0') {
ffffffffc020012a:	00044503          	lbu	a0,0(s0)
ffffffffc020012e:	008487bb          	addw	a5,s1,s0
ffffffffc0200132:	0405                	addi	s0,s0,1
ffffffffc0200134:	f96d                	bnez	a0,ffffffffc0200126 <cputs+0x16>
    (*cnt) ++;
ffffffffc0200136:	0017841b          	addiw	s0,a5,1
    cons_putc(c);
ffffffffc020013a:	4529                	li	a0,10
ffffffffc020013c:	336000ef          	jal	ra,ffffffffc0200472 <cons_putc>
        cputch(c, &cnt);
    }
    cputch('\n', &cnt);
    return cnt;
}
ffffffffc0200140:	60e2                	ld	ra,24(sp)
ffffffffc0200142:	8522                	mv	a0,s0
ffffffffc0200144:	6442                	ld	s0,16(sp)
ffffffffc0200146:	64a2                	ld	s1,8(sp)
ffffffffc0200148:	6105                	addi	sp,sp,32
ffffffffc020014a:	8082                	ret
    while ((c = *str ++) != '\0') {
ffffffffc020014c:	4405                	li	s0,1
ffffffffc020014e:	b7f5                	j	ffffffffc020013a <cputs+0x2a>

ffffffffc0200150 <getchar>:

/* getchar - reads a single non-zero character from stdin */
int
getchar(void) {
ffffffffc0200150:	1141                	addi	sp,sp,-16
ffffffffc0200152:	e406                	sd	ra,8(sp)
    int c;
    while ((c = cons_getc()) == 0)
ffffffffc0200154:	326000ef          	jal	ra,ffffffffc020047a <cons_getc>
ffffffffc0200158:	dd75                	beqz	a0,ffffffffc0200154 <getchar+0x4>
        /* do nothing */;
    return c;
}
ffffffffc020015a:	60a2                	ld	ra,8(sp)
ffffffffc020015c:	0141                	addi	sp,sp,16
ffffffffc020015e:	8082                	ret

ffffffffc0200160 <print_kerninfo>:
/* *
 * print_kerninfo - print the information about kernel, including the location
 * of kernel entry, the start addresses of data and text segements, the start
 * address of free memory and how many memory that kernel has used.
 * */
void print_kerninfo(void) {
ffffffffc0200160:	1141                	addi	sp,sp,-16
    extern char etext[], edata[], end[], kern_init[];
    cprintf("Special kernel symbols:\n");
ffffffffc0200162:	00002517          	auipc	a0,0x2
ffffffffc0200166:	e8e50513          	addi	a0,a0,-370 # ffffffffc0201ff0 <etext+0x20>
void print_kerninfo(void) {
ffffffffc020016a:	e406                	sd	ra,8(sp)
    cprintf("Special kernel symbols:\n");
ffffffffc020016c:	f6dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  entry  0x%016lx (virtual)\n", kern_init);
ffffffffc0200170:	00000597          	auipc	a1,0x0
ffffffffc0200174:	ee458593          	addi	a1,a1,-284 # ffffffffc0200054 <kern_init>
ffffffffc0200178:	00002517          	auipc	a0,0x2
ffffffffc020017c:	e9850513          	addi	a0,a0,-360 # ffffffffc0202010 <etext+0x40>
ffffffffc0200180:	f59ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  etext  0x%016lx (virtual)\n", etext);
ffffffffc0200184:	00002597          	auipc	a1,0x2
ffffffffc0200188:	e4c58593          	addi	a1,a1,-436 # ffffffffc0201fd0 <etext>
ffffffffc020018c:	00002517          	auipc	a0,0x2
ffffffffc0200190:	ea450513          	addi	a0,a0,-348 # ffffffffc0202030 <etext+0x60>
ffffffffc0200194:	f45ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  edata  0x%016lx (virtual)\n", edata);
ffffffffc0200198:	00007597          	auipc	a1,0x7
ffffffffc020019c:	e9058593          	addi	a1,a1,-368 # ffffffffc0207028 <free_area>
ffffffffc02001a0:	00002517          	auipc	a0,0x2
ffffffffc02001a4:	eb050513          	addi	a0,a0,-336 # ffffffffc0202050 <etext+0x80>
ffffffffc02001a8:	f31ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  end    0x%016lx (virtual)\n", end);
ffffffffc02001ac:	00007597          	auipc	a1,0x7
ffffffffc02001b0:	2ec58593          	addi	a1,a1,748 # ffffffffc0207498 <end>
ffffffffc02001b4:	00002517          	auipc	a0,0x2
ffffffffc02001b8:	ebc50513          	addi	a0,a0,-324 # ffffffffc0202070 <etext+0xa0>
ffffffffc02001bc:	f1dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("Kernel executable memory footprint: %dKB\n",
            (end - kern_init + 1023) / 1024);
ffffffffc02001c0:	00007597          	auipc	a1,0x7
ffffffffc02001c4:	6d758593          	addi	a1,a1,1751 # ffffffffc0207897 <end+0x3ff>
ffffffffc02001c8:	00000797          	auipc	a5,0x0
ffffffffc02001cc:	e8c78793          	addi	a5,a5,-372 # ffffffffc0200054 <kern_init>
ffffffffc02001d0:	40f587b3          	sub	a5,a1,a5
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02001d4:	43f7d593          	srai	a1,a5,0x3f
}
ffffffffc02001d8:	60a2                	ld	ra,8(sp)
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02001da:	3ff5f593          	andi	a1,a1,1023
ffffffffc02001de:	95be                	add	a1,a1,a5
ffffffffc02001e0:	85a9                	srai	a1,a1,0xa
ffffffffc02001e2:	00002517          	auipc	a0,0x2
ffffffffc02001e6:	eae50513          	addi	a0,a0,-338 # ffffffffc0202090 <etext+0xc0>
}
ffffffffc02001ea:	0141                	addi	sp,sp,16
    cprintf("Kernel executable memory footprint: %dKB\n",
ffffffffc02001ec:	b5f5                	j	ffffffffc02000d8 <cprintf>

ffffffffc02001ee <print_stackframe>:
 * Note that, the length of ebp-chain is limited. In boot/bootasm.S, before
 * jumping
 * to the kernel entry, the value of ebp has been set to zero, that's the
 * boundary.
 * */
void print_stackframe(void) {
ffffffffc02001ee:	1141                	addi	sp,sp,-16
    
    panic("Not Implemented!");
ffffffffc02001f0:	00002617          	auipc	a2,0x2
ffffffffc02001f4:	ed060613          	addi	a2,a2,-304 # ffffffffc02020c0 <etext+0xf0>
ffffffffc02001f8:	04e00593          	li	a1,78
ffffffffc02001fc:	00002517          	auipc	a0,0x2
ffffffffc0200200:	edc50513          	addi	a0,a0,-292 # ffffffffc02020d8 <etext+0x108>
void print_stackframe(void) {
ffffffffc0200204:	e406                	sd	ra,8(sp)
    panic("Not Implemented!");
ffffffffc0200206:	1cc000ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc020020a <mon_help>:
    }
}

/* mon_help - print the information about mon_* functions */
int
mon_help(int argc, char **argv, struct trapframe *tf) {
ffffffffc020020a:	1141                	addi	sp,sp,-16
    int i;
    for (i = 0; i < NCOMMANDS; i ++) {
        cprintf("%s - %s\n", commands[i].name, commands[i].desc);
ffffffffc020020c:	00002617          	auipc	a2,0x2
ffffffffc0200210:	ee460613          	addi	a2,a2,-284 # ffffffffc02020f0 <etext+0x120>
ffffffffc0200214:	00002597          	auipc	a1,0x2
ffffffffc0200218:	efc58593          	addi	a1,a1,-260 # ffffffffc0202110 <etext+0x140>
ffffffffc020021c:	00002517          	auipc	a0,0x2
ffffffffc0200220:	efc50513          	addi	a0,a0,-260 # ffffffffc0202118 <etext+0x148>
mon_help(int argc, char **argv, struct trapframe *tf) {
ffffffffc0200224:	e406                	sd	ra,8(sp)
        cprintf("%s - %s\n", commands[i].name, commands[i].desc);
ffffffffc0200226:	eb3ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
ffffffffc020022a:	00002617          	auipc	a2,0x2
ffffffffc020022e:	efe60613          	addi	a2,a2,-258 # ffffffffc0202128 <etext+0x158>
ffffffffc0200232:	00002597          	auipc	a1,0x2
ffffffffc0200236:	f1e58593          	addi	a1,a1,-226 # ffffffffc0202150 <etext+0x180>
ffffffffc020023a:	00002517          	auipc	a0,0x2
ffffffffc020023e:	ede50513          	addi	a0,a0,-290 # ffffffffc0202118 <etext+0x148>
ffffffffc0200242:	e97ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
ffffffffc0200246:	00002617          	auipc	a2,0x2
ffffffffc020024a:	f1a60613          	addi	a2,a2,-230 # ffffffffc0202160 <etext+0x190>
ffffffffc020024e:	00002597          	auipc	a1,0x2
ffffffffc0200252:	f3258593          	addi	a1,a1,-206 # ffffffffc0202180 <etext+0x1b0>
ffffffffc0200256:	00002517          	auipc	a0,0x2
ffffffffc020025a:	ec250513          	addi	a0,a0,-318 # ffffffffc0202118 <etext+0x148>
ffffffffc020025e:	e7bff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    }
    return 0;
}
ffffffffc0200262:	60a2                	ld	ra,8(sp)
ffffffffc0200264:	4501                	li	a0,0
ffffffffc0200266:	0141                	addi	sp,sp,16
ffffffffc0200268:	8082                	ret

ffffffffc020026a <mon_kerninfo>:
/* *
 * mon_kerninfo - call print_kerninfo in kern/debug/kdebug.c to
 * print the memory occupancy in kernel.
 * */
int
mon_kerninfo(int argc, char **argv, struct trapframe *tf) {
ffffffffc020026a:	1141                	addi	sp,sp,-16
ffffffffc020026c:	e406                	sd	ra,8(sp)
    print_kerninfo();
ffffffffc020026e:	ef3ff0ef          	jal	ra,ffffffffc0200160 <print_kerninfo>
    return 0;
}
ffffffffc0200272:	60a2                	ld	ra,8(sp)
ffffffffc0200274:	4501                	li	a0,0
ffffffffc0200276:	0141                	addi	sp,sp,16
ffffffffc0200278:	8082                	ret

ffffffffc020027a <mon_backtrace>:
/* *
 * mon_backtrace - call print_stackframe in kern/debug/kdebug.c to
 * print a backtrace of the stack.
 * */
int
mon_backtrace(int argc, char **argv, struct trapframe *tf) {
ffffffffc020027a:	1141                	addi	sp,sp,-16
ffffffffc020027c:	e406                	sd	ra,8(sp)
    print_stackframe();
ffffffffc020027e:	f71ff0ef          	jal	ra,ffffffffc02001ee <print_stackframe>
    return 0;
}
ffffffffc0200282:	60a2                	ld	ra,8(sp)
ffffffffc0200284:	4501                	li	a0,0
ffffffffc0200286:	0141                	addi	sp,sp,16
ffffffffc0200288:	8082                	ret

ffffffffc020028a <kmonitor>:
kmonitor(struct trapframe *tf) {
ffffffffc020028a:	7115                	addi	sp,sp,-224
ffffffffc020028c:	ed5e                	sd	s7,152(sp)
ffffffffc020028e:	8baa                	mv	s7,a0
    cprintf("Welcome to the kernel debug monitor!!\n");
ffffffffc0200290:	00002517          	auipc	a0,0x2
ffffffffc0200294:	f0050513          	addi	a0,a0,-256 # ffffffffc0202190 <etext+0x1c0>
kmonitor(struct trapframe *tf) {
ffffffffc0200298:	ed86                	sd	ra,216(sp)
ffffffffc020029a:	e9a2                	sd	s0,208(sp)
ffffffffc020029c:	e5a6                	sd	s1,200(sp)
ffffffffc020029e:	e1ca                	sd	s2,192(sp)
ffffffffc02002a0:	fd4e                	sd	s3,184(sp)
ffffffffc02002a2:	f952                	sd	s4,176(sp)
ffffffffc02002a4:	f556                	sd	s5,168(sp)
ffffffffc02002a6:	f15a                	sd	s6,160(sp)
ffffffffc02002a8:	e962                	sd	s8,144(sp)
ffffffffc02002aa:	e566                	sd	s9,136(sp)
ffffffffc02002ac:	e16a                	sd	s10,128(sp)
    cprintf("Welcome to the kernel debug monitor!!\n");
ffffffffc02002ae:	e2bff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("Type 'help' for a list of commands.\n");
ffffffffc02002b2:	00002517          	auipc	a0,0x2
ffffffffc02002b6:	f0650513          	addi	a0,a0,-250 # ffffffffc02021b8 <etext+0x1e8>
ffffffffc02002ba:	e1fff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    if (tf != NULL) {
ffffffffc02002be:	000b8563          	beqz	s7,ffffffffc02002c8 <kmonitor+0x3e>
        print_trapframe(tf);
ffffffffc02002c2:	855e                	mv	a0,s7
ffffffffc02002c4:	756000ef          	jal	ra,ffffffffc0200a1a <print_trapframe>
ffffffffc02002c8:	00002c17          	auipc	s8,0x2
ffffffffc02002cc:	f60c0c13          	addi	s8,s8,-160 # ffffffffc0202228 <commands>
        if ((buf = readline("K> ")) != NULL) {
ffffffffc02002d0:	00002917          	auipc	s2,0x2
ffffffffc02002d4:	f1090913          	addi	s2,s2,-240 # ffffffffc02021e0 <etext+0x210>
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc02002d8:	00002497          	auipc	s1,0x2
ffffffffc02002dc:	f1048493          	addi	s1,s1,-240 # ffffffffc02021e8 <etext+0x218>
        if (argc == MAXARGS - 1) {
ffffffffc02002e0:	49bd                	li	s3,15
            cprintf("Too many arguments (max %d).\n", MAXARGS);
ffffffffc02002e2:	00002b17          	auipc	s6,0x2
ffffffffc02002e6:	f0eb0b13          	addi	s6,s6,-242 # ffffffffc02021f0 <etext+0x220>
        argv[argc ++] = buf;
ffffffffc02002ea:	00002a17          	auipc	s4,0x2
ffffffffc02002ee:	e26a0a13          	addi	s4,s4,-474 # ffffffffc0202110 <etext+0x140>
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc02002f2:	4a8d                	li	s5,3
        if ((buf = readline("K> ")) != NULL) {
ffffffffc02002f4:	854a                	mv	a0,s2
ffffffffc02002f6:	31b010ef          	jal	ra,ffffffffc0201e10 <readline>
ffffffffc02002fa:	842a                	mv	s0,a0
ffffffffc02002fc:	dd65                	beqz	a0,ffffffffc02002f4 <kmonitor+0x6a>
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc02002fe:	00054583          	lbu	a1,0(a0)
    int argc = 0;
ffffffffc0200302:	4c81                	li	s9,0
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc0200304:	e1bd                	bnez	a1,ffffffffc020036a <kmonitor+0xe0>
    if (argc == 0) {
ffffffffc0200306:	fe0c87e3          	beqz	s9,ffffffffc02002f4 <kmonitor+0x6a>
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc020030a:	6582                	ld	a1,0(sp)
ffffffffc020030c:	00002d17          	auipc	s10,0x2
ffffffffc0200310:	f1cd0d13          	addi	s10,s10,-228 # ffffffffc0202228 <commands>
        argv[argc ++] = buf;
ffffffffc0200314:	8552                	mv	a0,s4
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc0200316:	4401                	li	s0,0
ffffffffc0200318:	0d61                	addi	s10,s10,24
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc020031a:	44b010ef          	jal	ra,ffffffffc0201f64 <strcmp>
ffffffffc020031e:	c919                	beqz	a0,ffffffffc0200334 <kmonitor+0xaa>
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc0200320:	2405                	addiw	s0,s0,1
ffffffffc0200322:	0b540063          	beq	s0,s5,ffffffffc02003c2 <kmonitor+0x138>
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc0200326:	000d3503          	ld	a0,0(s10)
ffffffffc020032a:	6582                	ld	a1,0(sp)
    for (i = 0; i < NCOMMANDS; i ++) {
ffffffffc020032c:	0d61                	addi	s10,s10,24
        if (strcmp(commands[i].name, argv[0]) == 0) {
ffffffffc020032e:	437010ef          	jal	ra,ffffffffc0201f64 <strcmp>
ffffffffc0200332:	f57d                	bnez	a0,ffffffffc0200320 <kmonitor+0x96>
            return commands[i].func(argc - 1, argv + 1, tf);
ffffffffc0200334:	00141793          	slli	a5,s0,0x1
ffffffffc0200338:	97a2                	add	a5,a5,s0
ffffffffc020033a:	078e                	slli	a5,a5,0x3
ffffffffc020033c:	97e2                	add	a5,a5,s8
ffffffffc020033e:	6b9c                	ld	a5,16(a5)
ffffffffc0200340:	865e                	mv	a2,s7
ffffffffc0200342:	002c                	addi	a1,sp,8
ffffffffc0200344:	fffc851b          	addiw	a0,s9,-1
ffffffffc0200348:	9782                	jalr	a5
            if (runcmd(buf, tf) < 0) {
ffffffffc020034a:	fa0555e3          	bgez	a0,ffffffffc02002f4 <kmonitor+0x6a>
}
ffffffffc020034e:	60ee                	ld	ra,216(sp)
ffffffffc0200350:	644e                	ld	s0,208(sp)
ffffffffc0200352:	64ae                	ld	s1,200(sp)
ffffffffc0200354:	690e                	ld	s2,192(sp)
ffffffffc0200356:	79ea                	ld	s3,184(sp)
ffffffffc0200358:	7a4a                	ld	s4,176(sp)
ffffffffc020035a:	7aaa                	ld	s5,168(sp)
ffffffffc020035c:	7b0a                	ld	s6,160(sp)
ffffffffc020035e:	6bea                	ld	s7,152(sp)
ffffffffc0200360:	6c4a                	ld	s8,144(sp)
ffffffffc0200362:	6caa                	ld	s9,136(sp)
ffffffffc0200364:	6d0a                	ld	s10,128(sp)
ffffffffc0200366:	612d                	addi	sp,sp,224
ffffffffc0200368:	8082                	ret
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc020036a:	8526                	mv	a0,s1
ffffffffc020036c:	43d010ef          	jal	ra,ffffffffc0201fa8 <strchr>
ffffffffc0200370:	c901                	beqz	a0,ffffffffc0200380 <kmonitor+0xf6>
ffffffffc0200372:	00144583          	lbu	a1,1(s0)
            *buf ++ = '\0';
ffffffffc0200376:	00040023          	sb	zero,0(s0)
ffffffffc020037a:	0405                	addi	s0,s0,1
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc020037c:	d5c9                	beqz	a1,ffffffffc0200306 <kmonitor+0x7c>
ffffffffc020037e:	b7f5                	j	ffffffffc020036a <kmonitor+0xe0>
        if (*buf == '\0') {
ffffffffc0200380:	00044783          	lbu	a5,0(s0)
ffffffffc0200384:	d3c9                	beqz	a5,ffffffffc0200306 <kmonitor+0x7c>
        if (argc == MAXARGS - 1) {
ffffffffc0200386:	033c8963          	beq	s9,s3,ffffffffc02003b8 <kmonitor+0x12e>
        argv[argc ++] = buf;
ffffffffc020038a:	003c9793          	slli	a5,s9,0x3
ffffffffc020038e:	0118                	addi	a4,sp,128
ffffffffc0200390:	97ba                	add	a5,a5,a4
ffffffffc0200392:	f887b023          	sd	s0,-128(a5)
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
ffffffffc0200396:	00044583          	lbu	a1,0(s0)
        argv[argc ++] = buf;
ffffffffc020039a:	2c85                	addiw	s9,s9,1
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
ffffffffc020039c:	e591                	bnez	a1,ffffffffc02003a8 <kmonitor+0x11e>
ffffffffc020039e:	b7b5                	j	ffffffffc020030a <kmonitor+0x80>
ffffffffc02003a0:	00144583          	lbu	a1,1(s0)
            buf ++;
ffffffffc02003a4:	0405                	addi	s0,s0,1
        while (*buf != '\0' && strchr(WHITESPACE, *buf) == NULL) {
ffffffffc02003a6:	d1a5                	beqz	a1,ffffffffc0200306 <kmonitor+0x7c>
ffffffffc02003a8:	8526                	mv	a0,s1
ffffffffc02003aa:	3ff010ef          	jal	ra,ffffffffc0201fa8 <strchr>
ffffffffc02003ae:	d96d                	beqz	a0,ffffffffc02003a0 <kmonitor+0x116>
        while (*buf != '\0' && strchr(WHITESPACE, *buf) != NULL) {
ffffffffc02003b0:	00044583          	lbu	a1,0(s0)
ffffffffc02003b4:	d9a9                	beqz	a1,ffffffffc0200306 <kmonitor+0x7c>
ffffffffc02003b6:	bf55                	j	ffffffffc020036a <kmonitor+0xe0>
            cprintf("Too many arguments (max %d).\n", MAXARGS);
ffffffffc02003b8:	45c1                	li	a1,16
ffffffffc02003ba:	855a                	mv	a0,s6
ffffffffc02003bc:	d1dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
ffffffffc02003c0:	b7e9                	j	ffffffffc020038a <kmonitor+0x100>
    cprintf("Unknown command '%s'\n", argv[0]);
ffffffffc02003c2:	6582                	ld	a1,0(sp)
ffffffffc02003c4:	00002517          	auipc	a0,0x2
ffffffffc02003c8:	e4c50513          	addi	a0,a0,-436 # ffffffffc0202210 <etext+0x240>
ffffffffc02003cc:	d0dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    return 0;
ffffffffc02003d0:	b715                	j	ffffffffc02002f4 <kmonitor+0x6a>

ffffffffc02003d2 <__panic>:
 * __panic - __panic is called on unresolvable fatal errors. it prints
 * "panic: 'message'", and then enters the kernel monitor.
 * */
void
__panic(const char *file, int line, const char *fmt, ...) {
    if (is_panic) {
ffffffffc02003d2:	00007317          	auipc	t1,0x7
ffffffffc02003d6:	06e30313          	addi	t1,t1,110 # ffffffffc0207440 <is_panic>
ffffffffc02003da:	00032e03          	lw	t3,0(t1)
__panic(const char *file, int line, const char *fmt, ...) {
ffffffffc02003de:	715d                	addi	sp,sp,-80
ffffffffc02003e0:	ec06                	sd	ra,24(sp)
ffffffffc02003e2:	e822                	sd	s0,16(sp)
ffffffffc02003e4:	f436                	sd	a3,40(sp)
ffffffffc02003e6:	f83a                	sd	a4,48(sp)
ffffffffc02003e8:	fc3e                	sd	a5,56(sp)
ffffffffc02003ea:	e0c2                	sd	a6,64(sp)
ffffffffc02003ec:	e4c6                	sd	a7,72(sp)
    if (is_panic) {
ffffffffc02003ee:	020e1a63          	bnez	t3,ffffffffc0200422 <__panic+0x50>
        goto panic_dead;
    }
    is_panic = 1;
ffffffffc02003f2:	4785                	li	a5,1
ffffffffc02003f4:	00f32023          	sw	a5,0(t1)

    // print the 'message'
    va_list ap;
    va_start(ap, fmt);
ffffffffc02003f8:	8432                	mv	s0,a2
ffffffffc02003fa:	103c                	addi	a5,sp,40
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc02003fc:	862e                	mv	a2,a1
ffffffffc02003fe:	85aa                	mv	a1,a0
ffffffffc0200400:	00002517          	auipc	a0,0x2
ffffffffc0200404:	e7050513          	addi	a0,a0,-400 # ffffffffc0202270 <commands+0x48>
    va_start(ap, fmt);
ffffffffc0200408:	e43e                	sd	a5,8(sp)
    cprintf("kernel panic at %s:%d:\n    ", file, line);
ffffffffc020040a:	ccfff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    vcprintf(fmt, ap);
ffffffffc020040e:	65a2                	ld	a1,8(sp)
ffffffffc0200410:	8522                	mv	a0,s0
ffffffffc0200412:	ca7ff0ef          	jal	ra,ffffffffc02000b8 <vcprintf>
    cprintf("\n");
ffffffffc0200416:	00002517          	auipc	a0,0x2
ffffffffc020041a:	ca250513          	addi	a0,a0,-862 # ffffffffc02020b8 <etext+0xe8>
ffffffffc020041e:	cbbff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    va_end(ap);

panic_dead:
    intr_disable();
ffffffffc0200422:	412000ef          	jal	ra,ffffffffc0200834 <intr_disable>
    while (1) {
        kmonitor(NULL);
ffffffffc0200426:	4501                	li	a0,0
ffffffffc0200428:	e63ff0ef          	jal	ra,ffffffffc020028a <kmonitor>
    while (1) {
ffffffffc020042c:	bfed                	j	ffffffffc0200426 <__panic+0x54>

ffffffffc020042e <clock_init>:

/* *
 * clock_init - initialize 8253 clock to interrupt 100 times per second,
 * and then enable IRQ_TIMER.
 * */
void clock_init(void) {
ffffffffc020042e:	1141                	addi	sp,sp,-16
ffffffffc0200430:	e406                	sd	ra,8(sp)
    // enable timer interrupt in sie
    set_csr(sie, MIP_STIP);
ffffffffc0200432:	02000793          	li	a5,32
ffffffffc0200436:	1047a7f3          	csrrs	a5,sie,a5
    __asm__ __volatile__("rdtime %0" : "=r"(n));
ffffffffc020043a:	c0102573          	rdtime	a0
    ticks = 0;

    cprintf("++ setup timer interrupts\n");
}

void clock_set_next_event(void) { sbi_set_timer(get_cycles() + timebase); }
ffffffffc020043e:	67e1                	lui	a5,0x18
ffffffffc0200440:	6a078793          	addi	a5,a5,1696 # 186a0 <kern_entry-0xffffffffc01e7960>
ffffffffc0200444:	953e                	add	a0,a0,a5
ffffffffc0200446:	299010ef          	jal	ra,ffffffffc0201ede <sbi_set_timer>
}
ffffffffc020044a:	60a2                	ld	ra,8(sp)
    ticks = 0;
ffffffffc020044c:	00007797          	auipc	a5,0x7
ffffffffc0200450:	fe07be23          	sd	zero,-4(a5) # ffffffffc0207448 <ticks>
    cprintf("++ setup timer interrupts\n");
ffffffffc0200454:	00002517          	auipc	a0,0x2
ffffffffc0200458:	e3c50513          	addi	a0,a0,-452 # ffffffffc0202290 <commands+0x68>
}
ffffffffc020045c:	0141                	addi	sp,sp,16
    cprintf("++ setup timer interrupts\n");
ffffffffc020045e:	b9ad                	j	ffffffffc02000d8 <cprintf>

ffffffffc0200460 <clock_set_next_event>:
    __asm__ __volatile__("rdtime %0" : "=r"(n));
ffffffffc0200460:	c0102573          	rdtime	a0
void clock_set_next_event(void) { sbi_set_timer(get_cycles() + timebase); }
ffffffffc0200464:	67e1                	lui	a5,0x18
ffffffffc0200466:	6a078793          	addi	a5,a5,1696 # 186a0 <kern_entry-0xffffffffc01e7960>
ffffffffc020046a:	953e                	add	a0,a0,a5
ffffffffc020046c:	2730106f          	j	ffffffffc0201ede <sbi_set_timer>

ffffffffc0200470 <cons_init>:

/* serial_intr - try to feed input characters from serial port */
void serial_intr(void) {}

/* cons_init - initializes the console devices */
void cons_init(void) {}
ffffffffc0200470:	8082                	ret

ffffffffc0200472 <cons_putc>:

/* cons_putc - print a single character @c to console devices */
void cons_putc(int c) { sbi_console_putchar((unsigned char)c); }
ffffffffc0200472:	0ff57513          	zext.b	a0,a0
ffffffffc0200476:	24f0106f          	j	ffffffffc0201ec4 <sbi_console_putchar>

ffffffffc020047a <cons_getc>:
 * cons_getc - return the next input character from console,
 * or 0 if none waiting.
 * */
int cons_getc(void) {
    int c = 0;
    c = sbi_console_getchar();
ffffffffc020047a:	27f0106f          	j	ffffffffc0201ef8 <sbi_console_getchar>

ffffffffc020047e <dtb_init>:

// 保存解析出的系统物理内存信息
static uint64_t memory_base = 0;
static uint64_t memory_size = 0;

void dtb_init(void) {
ffffffffc020047e:	7119                	addi	sp,sp,-128
    cprintf("DTB Init\n");
ffffffffc0200480:	00002517          	auipc	a0,0x2
ffffffffc0200484:	e3050513          	addi	a0,a0,-464 # ffffffffc02022b0 <commands+0x88>
void dtb_init(void) {
ffffffffc0200488:	fc86                	sd	ra,120(sp)
ffffffffc020048a:	f8a2                	sd	s0,112(sp)
ffffffffc020048c:	e8d2                	sd	s4,80(sp)
ffffffffc020048e:	f4a6                	sd	s1,104(sp)
ffffffffc0200490:	f0ca                	sd	s2,96(sp)
ffffffffc0200492:	ecce                	sd	s3,88(sp)
ffffffffc0200494:	e4d6                	sd	s5,72(sp)
ffffffffc0200496:	e0da                	sd	s6,64(sp)
ffffffffc0200498:	fc5e                	sd	s7,56(sp)
ffffffffc020049a:	f862                	sd	s8,48(sp)
ffffffffc020049c:	f466                	sd	s9,40(sp)
ffffffffc020049e:	f06a                	sd	s10,32(sp)
ffffffffc02004a0:	ec6e                	sd	s11,24(sp)
    cprintf("DTB Init\n");
ffffffffc02004a2:	c37ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("HartID: %ld\n", boot_hartid);
ffffffffc02004a6:	00007597          	auipc	a1,0x7
ffffffffc02004aa:	b5a5b583          	ld	a1,-1190(a1) # ffffffffc0207000 <boot_hartid>
ffffffffc02004ae:	00002517          	auipc	a0,0x2
ffffffffc02004b2:	e1250513          	addi	a0,a0,-494 # ffffffffc02022c0 <commands+0x98>
ffffffffc02004b6:	c23ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("DTB Address: 0x%lx\n", boot_dtb);
ffffffffc02004ba:	00007417          	auipc	s0,0x7
ffffffffc02004be:	b4e40413          	addi	s0,s0,-1202 # ffffffffc0207008 <boot_dtb>
ffffffffc02004c2:	600c                	ld	a1,0(s0)
ffffffffc02004c4:	00002517          	auipc	a0,0x2
ffffffffc02004c8:	e0c50513          	addi	a0,a0,-500 # ffffffffc02022d0 <commands+0xa8>
ffffffffc02004cc:	c0dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    
    if (boot_dtb == 0) {
ffffffffc02004d0:	00043a03          	ld	s4,0(s0)
        cprintf("Error: DTB address is null\n");
ffffffffc02004d4:	00002517          	auipc	a0,0x2
ffffffffc02004d8:	e1450513          	addi	a0,a0,-492 # ffffffffc02022e8 <commands+0xc0>
    if (boot_dtb == 0) {
ffffffffc02004dc:	120a0463          	beqz	s4,ffffffffc0200604 <dtb_init+0x186>
        return;
    }
    
    // 转换为虚拟地址
    uintptr_t dtb_vaddr = boot_dtb + PHYSICAL_MEMORY_OFFSET;
ffffffffc02004e0:	57f5                	li	a5,-3
ffffffffc02004e2:	07fa                	slli	a5,a5,0x1e
ffffffffc02004e4:	00fa0733          	add	a4,s4,a5
    const struct fdt_header *header = (const struct fdt_header *)dtb_vaddr;
    
    // 验证DTB
    uint32_t magic = fdt32_to_cpu(header->magic);
ffffffffc02004e8:	431c                	lw	a5,0(a4)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004ea:	00ff0637          	lui	a2,0xff0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004ee:	6b41                	lui	s6,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004f0:	0087d59b          	srliw	a1,a5,0x8
ffffffffc02004f4:	0187969b          	slliw	a3,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02004f8:	0187d51b          	srliw	a0,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02004fc:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200500:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200504:	8df1                	and	a1,a1,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200506:	8ec9                	or	a3,a3,a0
ffffffffc0200508:	0087979b          	slliw	a5,a5,0x8
ffffffffc020050c:	1b7d                	addi	s6,s6,-1
ffffffffc020050e:	0167f7b3          	and	a5,a5,s6
ffffffffc0200512:	8dd5                	or	a1,a1,a3
ffffffffc0200514:	8ddd                	or	a1,a1,a5
    if (magic != 0xd00dfeed) {
ffffffffc0200516:	d00e07b7          	lui	a5,0xd00e0
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020051a:	2581                	sext.w	a1,a1
    if (magic != 0xd00dfeed) {
ffffffffc020051c:	eed78793          	addi	a5,a5,-275 # ffffffffd00dfeed <end+0xfed8a55>
ffffffffc0200520:	10f59163          	bne	a1,a5,ffffffffc0200622 <dtb_init+0x1a4>
        return;
    }
    
    // 提取内存信息
    uint64_t mem_base, mem_size;
    if (extract_memory_info(dtb_vaddr, header, &mem_base, &mem_size) == 0) {
ffffffffc0200524:	471c                	lw	a5,8(a4)
ffffffffc0200526:	4754                	lw	a3,12(a4)
    int in_memory_node = 0;
ffffffffc0200528:	4c81                	li	s9,0
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020052a:	0087d59b          	srliw	a1,a5,0x8
ffffffffc020052e:	0086d51b          	srliw	a0,a3,0x8
ffffffffc0200532:	0186941b          	slliw	s0,a3,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200536:	0186d89b          	srliw	a7,a3,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020053a:	01879a1b          	slliw	s4,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020053e:	0187d81b          	srliw	a6,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200542:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200546:	0106d69b          	srliw	a3,a3,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020054a:	0105959b          	slliw	a1,a1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020054e:	0107d79b          	srliw	a5,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200552:	8d71                	and	a0,a0,a2
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200554:	01146433          	or	s0,s0,a7
ffffffffc0200558:	0086969b          	slliw	a3,a3,0x8
ffffffffc020055c:	010a6a33          	or	s4,s4,a6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200560:	8e6d                	and	a2,a2,a1
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200562:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200566:	8c49                	or	s0,s0,a0
ffffffffc0200568:	0166f6b3          	and	a3,a3,s6
ffffffffc020056c:	00ca6a33          	or	s4,s4,a2
ffffffffc0200570:	0167f7b3          	and	a5,a5,s6
ffffffffc0200574:	8c55                	or	s0,s0,a3
ffffffffc0200576:	00fa6a33          	or	s4,s4,a5
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020057a:	1402                	slli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc020057c:	1a02                	slli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc020057e:	9001                	srli	s0,s0,0x20
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200580:	020a5a13          	srli	s4,s4,0x20
    const char *strings_base = (const char *)(dtb_vaddr + strings_offset);
ffffffffc0200584:	943a                	add	s0,s0,a4
    const uint32_t *struct_ptr = (const uint32_t *)(dtb_vaddr + struct_offset);
ffffffffc0200586:	9a3a                	add	s4,s4,a4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200588:	00ff0c37          	lui	s8,0xff0
        switch (token) {
ffffffffc020058c:	4b8d                	li	s7,3
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc020058e:	00002917          	auipc	s2,0x2
ffffffffc0200592:	daa90913          	addi	s2,s2,-598 # ffffffffc0202338 <commands+0x110>
ffffffffc0200596:	49bd                	li	s3,15
        switch (token) {
ffffffffc0200598:	4d91                	li	s11,4
ffffffffc020059a:	4d05                	li	s10,1
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc020059c:	00002497          	auipc	s1,0x2
ffffffffc02005a0:	d9448493          	addi	s1,s1,-620 # ffffffffc0202330 <commands+0x108>
        uint32_t token = fdt32_to_cpu(*struct_ptr++);
ffffffffc02005a4:	000a2703          	lw	a4,0(s4)
ffffffffc02005a8:	004a0a93          	addi	s5,s4,4
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02005ac:	0087569b          	srliw	a3,a4,0x8
ffffffffc02005b0:	0187179b          	slliw	a5,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02005b4:	0187561b          	srliw	a2,a4,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02005b8:	0106969b          	slliw	a3,a3,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02005bc:	0107571b          	srliw	a4,a4,0x10
ffffffffc02005c0:	8fd1                	or	a5,a5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02005c2:	0186f6b3          	and	a3,a3,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02005c6:	0087171b          	slliw	a4,a4,0x8
ffffffffc02005ca:	8fd5                	or	a5,a5,a3
ffffffffc02005cc:	00eb7733          	and	a4,s6,a4
ffffffffc02005d0:	8fd9                	or	a5,a5,a4
ffffffffc02005d2:	2781                	sext.w	a5,a5
        switch (token) {
ffffffffc02005d4:	09778c63          	beq	a5,s7,ffffffffc020066c <dtb_init+0x1ee>
ffffffffc02005d8:	00fbea63          	bltu	s7,a5,ffffffffc02005ec <dtb_init+0x16e>
ffffffffc02005dc:	07a78663          	beq	a5,s10,ffffffffc0200648 <dtb_init+0x1ca>
ffffffffc02005e0:	4709                	li	a4,2
ffffffffc02005e2:	00e79763          	bne	a5,a4,ffffffffc02005f0 <dtb_init+0x172>
ffffffffc02005e6:	4c81                	li	s9,0
ffffffffc02005e8:	8a56                	mv	s4,s5
ffffffffc02005ea:	bf6d                	j	ffffffffc02005a4 <dtb_init+0x126>
ffffffffc02005ec:	ffb78ee3          	beq	a5,s11,ffffffffc02005e8 <dtb_init+0x16a>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
        // 保存到全局变量，供 PMM 查询
        memory_base = mem_base;
        memory_size = mem_size;
    } else {
        cprintf("Warning: Could not extract memory info from DTB\n");
ffffffffc02005f0:	00002517          	auipc	a0,0x2
ffffffffc02005f4:	dc050513          	addi	a0,a0,-576 # ffffffffc02023b0 <commands+0x188>
ffffffffc02005f8:	ae1ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    }
    cprintf("DTB init completed\n");
ffffffffc02005fc:	00002517          	auipc	a0,0x2
ffffffffc0200600:	dec50513          	addi	a0,a0,-532 # ffffffffc02023e8 <commands+0x1c0>
}
ffffffffc0200604:	7446                	ld	s0,112(sp)
ffffffffc0200606:	70e6                	ld	ra,120(sp)
ffffffffc0200608:	74a6                	ld	s1,104(sp)
ffffffffc020060a:	7906                	ld	s2,96(sp)
ffffffffc020060c:	69e6                	ld	s3,88(sp)
ffffffffc020060e:	6a46                	ld	s4,80(sp)
ffffffffc0200610:	6aa6                	ld	s5,72(sp)
ffffffffc0200612:	6b06                	ld	s6,64(sp)
ffffffffc0200614:	7be2                	ld	s7,56(sp)
ffffffffc0200616:	7c42                	ld	s8,48(sp)
ffffffffc0200618:	7ca2                	ld	s9,40(sp)
ffffffffc020061a:	7d02                	ld	s10,32(sp)
ffffffffc020061c:	6de2                	ld	s11,24(sp)
ffffffffc020061e:	6109                	addi	sp,sp,128
    cprintf("DTB init completed\n");
ffffffffc0200620:	bc65                	j	ffffffffc02000d8 <cprintf>
}
ffffffffc0200622:	7446                	ld	s0,112(sp)
ffffffffc0200624:	70e6                	ld	ra,120(sp)
ffffffffc0200626:	74a6                	ld	s1,104(sp)
ffffffffc0200628:	7906                	ld	s2,96(sp)
ffffffffc020062a:	69e6                	ld	s3,88(sp)
ffffffffc020062c:	6a46                	ld	s4,80(sp)
ffffffffc020062e:	6aa6                	ld	s5,72(sp)
ffffffffc0200630:	6b06                	ld	s6,64(sp)
ffffffffc0200632:	7be2                	ld	s7,56(sp)
ffffffffc0200634:	7c42                	ld	s8,48(sp)
ffffffffc0200636:	7ca2                	ld	s9,40(sp)
ffffffffc0200638:	7d02                	ld	s10,32(sp)
ffffffffc020063a:	6de2                	ld	s11,24(sp)
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc020063c:	00002517          	auipc	a0,0x2
ffffffffc0200640:	ccc50513          	addi	a0,a0,-820 # ffffffffc0202308 <commands+0xe0>
}
ffffffffc0200644:	6109                	addi	sp,sp,128
        cprintf("Error: Invalid DTB magic number: 0x%x\n", magic);
ffffffffc0200646:	bc49                	j	ffffffffc02000d8 <cprintf>
                int name_len = strlen(name);
ffffffffc0200648:	8556                	mv	a0,s5
ffffffffc020064a:	0e5010ef          	jal	ra,ffffffffc0201f2e <strlen>
ffffffffc020064e:	8a2a                	mv	s4,a0
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200650:	4619                	li	a2,6
ffffffffc0200652:	85a6                	mv	a1,s1
ffffffffc0200654:	8556                	mv	a0,s5
                int name_len = strlen(name);
ffffffffc0200656:	2a01                	sext.w	s4,s4
                if (strncmp(name, "memory", 6) == 0) {
ffffffffc0200658:	12b010ef          	jal	ra,ffffffffc0201f82 <strncmp>
ffffffffc020065c:	e111                	bnez	a0,ffffffffc0200660 <dtb_init+0x1e2>
                    in_memory_node = 1;
ffffffffc020065e:	4c85                	li	s9,1
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + name_len + 4) & ~3);
ffffffffc0200660:	0a91                	addi	s5,s5,4
ffffffffc0200662:	9ad2                	add	s5,s5,s4
ffffffffc0200664:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc0200668:	8a56                	mv	s4,s5
ffffffffc020066a:	bf2d                	j	ffffffffc02005a4 <dtb_init+0x126>
                uint32_t prop_len = fdt32_to_cpu(*struct_ptr++);
ffffffffc020066c:	004a2783          	lw	a5,4(s4)
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc0200670:	00ca0693          	addi	a3,s4,12
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200674:	0087d71b          	srliw	a4,a5,0x8
ffffffffc0200678:	01879a9b          	slliw	s5,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020067c:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200680:	0107171b          	slliw	a4,a4,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200684:	0107d79b          	srliw	a5,a5,0x10
ffffffffc0200688:	00caeab3          	or	s5,s5,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020068c:	01877733          	and	a4,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200690:	0087979b          	slliw	a5,a5,0x8
ffffffffc0200694:	00eaeab3          	or	s5,s5,a4
ffffffffc0200698:	00fb77b3          	and	a5,s6,a5
ffffffffc020069c:	00faeab3          	or	s5,s5,a5
ffffffffc02006a0:	2a81                	sext.w	s5,s5
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc02006a2:	000c9c63          	bnez	s9,ffffffffc02006ba <dtb_init+0x23c>
                struct_ptr = (const uint32_t *)(((uintptr_t)struct_ptr + prop_len + 3) & ~3);
ffffffffc02006a6:	1a82                	slli	s5,s5,0x20
ffffffffc02006a8:	00368793          	addi	a5,a3,3
ffffffffc02006ac:	020ada93          	srli	s5,s5,0x20
ffffffffc02006b0:	9abe                	add	s5,s5,a5
ffffffffc02006b2:	ffcafa93          	andi	s5,s5,-4
        switch (token) {
ffffffffc02006b6:	8a56                	mv	s4,s5
ffffffffc02006b8:	b5f5                	j	ffffffffc02005a4 <dtb_init+0x126>
                uint32_t prop_nameoff = fdt32_to_cpu(*struct_ptr++);
ffffffffc02006ba:	008a2783          	lw	a5,8(s4)
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc02006be:	85ca                	mv	a1,s2
ffffffffc02006c0:	e436                	sd	a3,8(sp)
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02006c2:	0087d51b          	srliw	a0,a5,0x8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02006c6:	0187d61b          	srliw	a2,a5,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02006ca:	0187971b          	slliw	a4,a5,0x18
ffffffffc02006ce:	0105151b          	slliw	a0,a0,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02006d2:	0107d79b          	srliw	a5,a5,0x10
ffffffffc02006d6:	8f51                	or	a4,a4,a2
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc02006d8:	01857533          	and	a0,a0,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc02006dc:	0087979b          	slliw	a5,a5,0x8
ffffffffc02006e0:	8d59                	or	a0,a0,a4
ffffffffc02006e2:	00fb77b3          	and	a5,s6,a5
ffffffffc02006e6:	8d5d                	or	a0,a0,a5
                const char *prop_name = strings_base + prop_nameoff;
ffffffffc02006e8:	1502                	slli	a0,a0,0x20
ffffffffc02006ea:	9101                	srli	a0,a0,0x20
                if (in_memory_node && strcmp(prop_name, "reg") == 0 && prop_len >= 16) {
ffffffffc02006ec:	9522                	add	a0,a0,s0
ffffffffc02006ee:	077010ef          	jal	ra,ffffffffc0201f64 <strcmp>
ffffffffc02006f2:	66a2                	ld	a3,8(sp)
ffffffffc02006f4:	f94d                	bnez	a0,ffffffffc02006a6 <dtb_init+0x228>
ffffffffc02006f6:	fb59f8e3          	bgeu	s3,s5,ffffffffc02006a6 <dtb_init+0x228>
                    *mem_base = fdt64_to_cpu(reg_data[0]);
ffffffffc02006fa:	00ca3783          	ld	a5,12(s4)
                    *mem_size = fdt64_to_cpu(reg_data[1]);
ffffffffc02006fe:	014a3703          	ld	a4,20(s4)
        cprintf("Physical Memory from DTB:\n");
ffffffffc0200702:	00002517          	auipc	a0,0x2
ffffffffc0200706:	c3e50513          	addi	a0,a0,-962 # ffffffffc0202340 <commands+0x118>
           fdt32_to_cpu(x >> 32);
ffffffffc020070a:	4207d613          	srai	a2,a5,0x20
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020070e:	0087d31b          	srliw	t1,a5,0x8
           fdt32_to_cpu(x >> 32);
ffffffffc0200712:	42075593          	srai	a1,a4,0x20
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200716:	0187de1b          	srliw	t3,a5,0x18
ffffffffc020071a:	0186581b          	srliw	a6,a2,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020071e:	0187941b          	slliw	s0,a5,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200722:	0107d89b          	srliw	a7,a5,0x10
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200726:	0187d693          	srli	a3,a5,0x18
ffffffffc020072a:	01861f1b          	slliw	t5,a2,0x18
ffffffffc020072e:	0087579b          	srliw	a5,a4,0x8
ffffffffc0200732:	0103131b          	slliw	t1,t1,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200736:	0106561b          	srliw	a2,a2,0x10
ffffffffc020073a:	010f6f33          	or	t5,t5,a6
ffffffffc020073e:	0187529b          	srliw	t0,a4,0x18
ffffffffc0200742:	0185df9b          	srliw	t6,a1,0x18
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200746:	01837333          	and	t1,t1,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020074a:	01c46433          	or	s0,s0,t3
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc020074e:	0186f6b3          	and	a3,a3,s8
ffffffffc0200752:	01859e1b          	slliw	t3,a1,0x18
ffffffffc0200756:	01871e9b          	slliw	t4,a4,0x18
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020075a:	0107581b          	srliw	a6,a4,0x10
ffffffffc020075e:	0086161b          	slliw	a2,a2,0x8
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200762:	8361                	srli	a4,a4,0x18
ffffffffc0200764:	0107979b          	slliw	a5,a5,0x10
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200768:	0105d59b          	srliw	a1,a1,0x10
ffffffffc020076c:	01e6e6b3          	or	a3,a3,t5
ffffffffc0200770:	00cb7633          	and	a2,s6,a2
ffffffffc0200774:	0088181b          	slliw	a6,a6,0x8
ffffffffc0200778:	0085959b          	slliw	a1,a1,0x8
ffffffffc020077c:	00646433          	or	s0,s0,t1
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200780:	0187f7b3          	and	a5,a5,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc0200784:	01fe6333          	or	t1,t3,t6
    return ((x & 0xff) << 24) | (((x >> 8) & 0xff) << 16) | 
ffffffffc0200788:	01877c33          	and	s8,a4,s8
           (((x >> 16) & 0xff) << 8) | ((x >> 24) & 0xff);
ffffffffc020078c:	0088989b          	slliw	a7,a7,0x8
ffffffffc0200790:	011b78b3          	and	a7,s6,a7
ffffffffc0200794:	005eeeb3          	or	t4,t4,t0
ffffffffc0200798:	00c6e733          	or	a4,a3,a2
ffffffffc020079c:	006c6c33          	or	s8,s8,t1
ffffffffc02007a0:	010b76b3          	and	a3,s6,a6
ffffffffc02007a4:	00bb7b33          	and	s6,s6,a1
ffffffffc02007a8:	01d7e7b3          	or	a5,a5,t4
ffffffffc02007ac:	016c6b33          	or	s6,s8,s6
ffffffffc02007b0:	01146433          	or	s0,s0,a7
ffffffffc02007b4:	8fd5                	or	a5,a5,a3
           fdt32_to_cpu(x >> 32);
ffffffffc02007b6:	1702                	slli	a4,a4,0x20
ffffffffc02007b8:	1b02                	slli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc02007ba:	1782                	slli	a5,a5,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc02007bc:	9301                	srli	a4,a4,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc02007be:	1402                	slli	s0,s0,0x20
           fdt32_to_cpu(x >> 32);
ffffffffc02007c0:	020b5b13          	srli	s6,s6,0x20
    return ((uint64_t)fdt32_to_cpu(x & 0xffffffff) << 32) | 
ffffffffc02007c4:	0167eb33          	or	s6,a5,s6
ffffffffc02007c8:	8c59                	or	s0,s0,a4
        cprintf("Physical Memory from DTB:\n");
ffffffffc02007ca:	90fff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
        cprintf("  Base: 0x%016lx\n", mem_base);
ffffffffc02007ce:	85a2                	mv	a1,s0
ffffffffc02007d0:	00002517          	auipc	a0,0x2
ffffffffc02007d4:	b9050513          	addi	a0,a0,-1136 # ffffffffc0202360 <commands+0x138>
ffffffffc02007d8:	901ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
        cprintf("  Size: 0x%016lx (%ld MB)\n", mem_size, mem_size / (1024 * 1024));
ffffffffc02007dc:	014b5613          	srli	a2,s6,0x14
ffffffffc02007e0:	85da                	mv	a1,s6
ffffffffc02007e2:	00002517          	auipc	a0,0x2
ffffffffc02007e6:	b9650513          	addi	a0,a0,-1130 # ffffffffc0202378 <commands+0x150>
ffffffffc02007ea:	8efff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
        cprintf("  End:  0x%016lx\n", mem_base + mem_size - 1);
ffffffffc02007ee:	008b05b3          	add	a1,s6,s0
ffffffffc02007f2:	15fd                	addi	a1,a1,-1
ffffffffc02007f4:	00002517          	auipc	a0,0x2
ffffffffc02007f8:	ba450513          	addi	a0,a0,-1116 # ffffffffc0202398 <commands+0x170>
ffffffffc02007fc:	8ddff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("DTB init completed\n");
ffffffffc0200800:	00002517          	auipc	a0,0x2
ffffffffc0200804:	be850513          	addi	a0,a0,-1048 # ffffffffc02023e8 <commands+0x1c0>
        memory_base = mem_base;
ffffffffc0200808:	00007797          	auipc	a5,0x7
ffffffffc020080c:	c487b423          	sd	s0,-952(a5) # ffffffffc0207450 <memory_base>
        memory_size = mem_size;
ffffffffc0200810:	00007797          	auipc	a5,0x7
ffffffffc0200814:	c567b423          	sd	s6,-952(a5) # ffffffffc0207458 <memory_size>
    cprintf("DTB init completed\n");
ffffffffc0200818:	b3f5                	j	ffffffffc0200604 <dtb_init+0x186>

ffffffffc020081a <get_memory_base>:

uint64_t get_memory_base(void) {
    return memory_base;
}
ffffffffc020081a:	00007517          	auipc	a0,0x7
ffffffffc020081e:	c3653503          	ld	a0,-970(a0) # ffffffffc0207450 <memory_base>
ffffffffc0200822:	8082                	ret

ffffffffc0200824 <get_memory_size>:

uint64_t get_memory_size(void) {
    return memory_size;
}
ffffffffc0200824:	00007517          	auipc	a0,0x7
ffffffffc0200828:	c3453503          	ld	a0,-972(a0) # ffffffffc0207458 <memory_size>
ffffffffc020082c:	8082                	ret

ffffffffc020082e <intr_enable>:
#include <intr.h>
#include <riscv.h>

/* intr_enable - enable irq interrupt */
void intr_enable(void) { set_csr(sstatus, SSTATUS_SIE); }
ffffffffc020082e:	100167f3          	csrrsi	a5,sstatus,2
ffffffffc0200832:	8082                	ret

ffffffffc0200834 <intr_disable>:

/* intr_disable - disable irq interrupt */
void intr_disable(void) { clear_csr(sstatus, SSTATUS_SIE); }
ffffffffc0200834:	100177f3          	csrrci	a5,sstatus,2
ffffffffc0200838:	8082                	ret

ffffffffc020083a <idt_init>:
void idt_init(void) {

    extern void __alltraps(void);
    /* Set sup0 scratch register to 0, indicating to exception vector
       that we are presently executing in the kernel */
    write_csr(sscratch, 0);
ffffffffc020083a:	14005073          	csrwi	sscratch,0
    /* Set the exception vector address */
    write_csr(stvec, &__alltraps);
ffffffffc020083e:	00000797          	auipc	a5,0x0
ffffffffc0200842:	35278793          	addi	a5,a5,850 # ffffffffc0200b90 <__alltraps>
ffffffffc0200846:	10579073          	csrw	stvec,a5
}
ffffffffc020084a:	8082                	ret

ffffffffc020084c <print_regs>:
    cprintf("  badvaddr 0x%08x\n", tf->badvaddr);
    cprintf("  cause    0x%08x\n", tf->cause);
}

void print_regs(struct pushregs *gpr) {
    cprintf("  zero     0x%08x\n", gpr->zero);
ffffffffc020084c:	610c                	ld	a1,0(a0)
void print_regs(struct pushregs *gpr) {
ffffffffc020084e:	1141                	addi	sp,sp,-16
ffffffffc0200850:	e022                	sd	s0,0(sp)
ffffffffc0200852:	842a                	mv	s0,a0
    cprintf("  zero     0x%08x\n", gpr->zero);
ffffffffc0200854:	00002517          	auipc	a0,0x2
ffffffffc0200858:	bac50513          	addi	a0,a0,-1108 # ffffffffc0202400 <commands+0x1d8>
void print_regs(struct pushregs *gpr) {
ffffffffc020085c:	e406                	sd	ra,8(sp)
    cprintf("  zero     0x%08x\n", gpr->zero);
ffffffffc020085e:	87bff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  ra       0x%08x\n", gpr->ra);
ffffffffc0200862:	640c                	ld	a1,8(s0)
ffffffffc0200864:	00002517          	auipc	a0,0x2
ffffffffc0200868:	bb450513          	addi	a0,a0,-1100 # ffffffffc0202418 <commands+0x1f0>
ffffffffc020086c:	86dff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  sp       0x%08x\n", gpr->sp);
ffffffffc0200870:	680c                	ld	a1,16(s0)
ffffffffc0200872:	00002517          	auipc	a0,0x2
ffffffffc0200876:	bbe50513          	addi	a0,a0,-1090 # ffffffffc0202430 <commands+0x208>
ffffffffc020087a:	85fff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  gp       0x%08x\n", gpr->gp);
ffffffffc020087e:	6c0c                	ld	a1,24(s0)
ffffffffc0200880:	00002517          	auipc	a0,0x2
ffffffffc0200884:	bc850513          	addi	a0,a0,-1080 # ffffffffc0202448 <commands+0x220>
ffffffffc0200888:	851ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  tp       0x%08x\n", gpr->tp);
ffffffffc020088c:	700c                	ld	a1,32(s0)
ffffffffc020088e:	00002517          	auipc	a0,0x2
ffffffffc0200892:	bd250513          	addi	a0,a0,-1070 # ffffffffc0202460 <commands+0x238>
ffffffffc0200896:	843ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t0       0x%08x\n", gpr->t0);
ffffffffc020089a:	740c                	ld	a1,40(s0)
ffffffffc020089c:	00002517          	auipc	a0,0x2
ffffffffc02008a0:	bdc50513          	addi	a0,a0,-1060 # ffffffffc0202478 <commands+0x250>
ffffffffc02008a4:	835ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t1       0x%08x\n", gpr->t1);
ffffffffc02008a8:	780c                	ld	a1,48(s0)
ffffffffc02008aa:	00002517          	auipc	a0,0x2
ffffffffc02008ae:	be650513          	addi	a0,a0,-1050 # ffffffffc0202490 <commands+0x268>
ffffffffc02008b2:	827ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t2       0x%08x\n", gpr->t2);
ffffffffc02008b6:	7c0c                	ld	a1,56(s0)
ffffffffc02008b8:	00002517          	auipc	a0,0x2
ffffffffc02008bc:	bf050513          	addi	a0,a0,-1040 # ffffffffc02024a8 <commands+0x280>
ffffffffc02008c0:	819ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s0       0x%08x\n", gpr->s0);
ffffffffc02008c4:	602c                	ld	a1,64(s0)
ffffffffc02008c6:	00002517          	auipc	a0,0x2
ffffffffc02008ca:	bfa50513          	addi	a0,a0,-1030 # ffffffffc02024c0 <commands+0x298>
ffffffffc02008ce:	80bff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s1       0x%08x\n", gpr->s1);
ffffffffc02008d2:	642c                	ld	a1,72(s0)
ffffffffc02008d4:	00002517          	auipc	a0,0x2
ffffffffc02008d8:	c0450513          	addi	a0,a0,-1020 # ffffffffc02024d8 <commands+0x2b0>
ffffffffc02008dc:	ffcff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a0       0x%08x\n", gpr->a0);
ffffffffc02008e0:	682c                	ld	a1,80(s0)
ffffffffc02008e2:	00002517          	auipc	a0,0x2
ffffffffc02008e6:	c0e50513          	addi	a0,a0,-1010 # ffffffffc02024f0 <commands+0x2c8>
ffffffffc02008ea:	feeff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a1       0x%08x\n", gpr->a1);
ffffffffc02008ee:	6c2c                	ld	a1,88(s0)
ffffffffc02008f0:	00002517          	auipc	a0,0x2
ffffffffc02008f4:	c1850513          	addi	a0,a0,-1000 # ffffffffc0202508 <commands+0x2e0>
ffffffffc02008f8:	fe0ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a2       0x%08x\n", gpr->a2);
ffffffffc02008fc:	702c                	ld	a1,96(s0)
ffffffffc02008fe:	00002517          	auipc	a0,0x2
ffffffffc0200902:	c2250513          	addi	a0,a0,-990 # ffffffffc0202520 <commands+0x2f8>
ffffffffc0200906:	fd2ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a3       0x%08x\n", gpr->a3);
ffffffffc020090a:	742c                	ld	a1,104(s0)
ffffffffc020090c:	00002517          	auipc	a0,0x2
ffffffffc0200910:	c2c50513          	addi	a0,a0,-980 # ffffffffc0202538 <commands+0x310>
ffffffffc0200914:	fc4ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a4       0x%08x\n", gpr->a4);
ffffffffc0200918:	782c                	ld	a1,112(s0)
ffffffffc020091a:	00002517          	auipc	a0,0x2
ffffffffc020091e:	c3650513          	addi	a0,a0,-970 # ffffffffc0202550 <commands+0x328>
ffffffffc0200922:	fb6ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a5       0x%08x\n", gpr->a5);
ffffffffc0200926:	7c2c                	ld	a1,120(s0)
ffffffffc0200928:	00002517          	auipc	a0,0x2
ffffffffc020092c:	c4050513          	addi	a0,a0,-960 # ffffffffc0202568 <commands+0x340>
ffffffffc0200930:	fa8ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a6       0x%08x\n", gpr->a6);
ffffffffc0200934:	604c                	ld	a1,128(s0)
ffffffffc0200936:	00002517          	auipc	a0,0x2
ffffffffc020093a:	c4a50513          	addi	a0,a0,-950 # ffffffffc0202580 <commands+0x358>
ffffffffc020093e:	f9aff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  a7       0x%08x\n", gpr->a7);
ffffffffc0200942:	644c                	ld	a1,136(s0)
ffffffffc0200944:	00002517          	auipc	a0,0x2
ffffffffc0200948:	c5450513          	addi	a0,a0,-940 # ffffffffc0202598 <commands+0x370>
ffffffffc020094c:	f8cff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s2       0x%08x\n", gpr->s2);
ffffffffc0200950:	684c                	ld	a1,144(s0)
ffffffffc0200952:	00002517          	auipc	a0,0x2
ffffffffc0200956:	c5e50513          	addi	a0,a0,-930 # ffffffffc02025b0 <commands+0x388>
ffffffffc020095a:	f7eff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s3       0x%08x\n", gpr->s3);
ffffffffc020095e:	6c4c                	ld	a1,152(s0)
ffffffffc0200960:	00002517          	auipc	a0,0x2
ffffffffc0200964:	c6850513          	addi	a0,a0,-920 # ffffffffc02025c8 <commands+0x3a0>
ffffffffc0200968:	f70ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s4       0x%08x\n", gpr->s4);
ffffffffc020096c:	704c                	ld	a1,160(s0)
ffffffffc020096e:	00002517          	auipc	a0,0x2
ffffffffc0200972:	c7250513          	addi	a0,a0,-910 # ffffffffc02025e0 <commands+0x3b8>
ffffffffc0200976:	f62ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s5       0x%08x\n", gpr->s5);
ffffffffc020097a:	744c                	ld	a1,168(s0)
ffffffffc020097c:	00002517          	auipc	a0,0x2
ffffffffc0200980:	c7c50513          	addi	a0,a0,-900 # ffffffffc02025f8 <commands+0x3d0>
ffffffffc0200984:	f54ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s6       0x%08x\n", gpr->s6);
ffffffffc0200988:	784c                	ld	a1,176(s0)
ffffffffc020098a:	00002517          	auipc	a0,0x2
ffffffffc020098e:	c8650513          	addi	a0,a0,-890 # ffffffffc0202610 <commands+0x3e8>
ffffffffc0200992:	f46ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s7       0x%08x\n", gpr->s7);
ffffffffc0200996:	7c4c                	ld	a1,184(s0)
ffffffffc0200998:	00002517          	auipc	a0,0x2
ffffffffc020099c:	c9050513          	addi	a0,a0,-880 # ffffffffc0202628 <commands+0x400>
ffffffffc02009a0:	f38ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s8       0x%08x\n", gpr->s8);
ffffffffc02009a4:	606c                	ld	a1,192(s0)
ffffffffc02009a6:	00002517          	auipc	a0,0x2
ffffffffc02009aa:	c9a50513          	addi	a0,a0,-870 # ffffffffc0202640 <commands+0x418>
ffffffffc02009ae:	f2aff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s9       0x%08x\n", gpr->s9);
ffffffffc02009b2:	646c                	ld	a1,200(s0)
ffffffffc02009b4:	00002517          	auipc	a0,0x2
ffffffffc02009b8:	ca450513          	addi	a0,a0,-860 # ffffffffc0202658 <commands+0x430>
ffffffffc02009bc:	f1cff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s10      0x%08x\n", gpr->s10);
ffffffffc02009c0:	686c                	ld	a1,208(s0)
ffffffffc02009c2:	00002517          	auipc	a0,0x2
ffffffffc02009c6:	cae50513          	addi	a0,a0,-850 # ffffffffc0202670 <commands+0x448>
ffffffffc02009ca:	f0eff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  s11      0x%08x\n", gpr->s11);
ffffffffc02009ce:	6c6c                	ld	a1,216(s0)
ffffffffc02009d0:	00002517          	auipc	a0,0x2
ffffffffc02009d4:	cb850513          	addi	a0,a0,-840 # ffffffffc0202688 <commands+0x460>
ffffffffc02009d8:	f00ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t3       0x%08x\n", gpr->t3);
ffffffffc02009dc:	706c                	ld	a1,224(s0)
ffffffffc02009de:	00002517          	auipc	a0,0x2
ffffffffc02009e2:	cc250513          	addi	a0,a0,-830 # ffffffffc02026a0 <commands+0x478>
ffffffffc02009e6:	ef2ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t4       0x%08x\n", gpr->t4);
ffffffffc02009ea:	746c                	ld	a1,232(s0)
ffffffffc02009ec:	00002517          	auipc	a0,0x2
ffffffffc02009f0:	ccc50513          	addi	a0,a0,-820 # ffffffffc02026b8 <commands+0x490>
ffffffffc02009f4:	ee4ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t5       0x%08x\n", gpr->t5);
ffffffffc02009f8:	786c                	ld	a1,240(s0)
ffffffffc02009fa:	00002517          	auipc	a0,0x2
ffffffffc02009fe:	cd650513          	addi	a0,a0,-810 # ffffffffc02026d0 <commands+0x4a8>
ffffffffc0200a02:	ed6ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  t6       0x%08x\n", gpr->t6);
ffffffffc0200a06:	7c6c                	ld	a1,248(s0)
}
ffffffffc0200a08:	6402                	ld	s0,0(sp)
ffffffffc0200a0a:	60a2                	ld	ra,8(sp)
    cprintf("  t6       0x%08x\n", gpr->t6);
ffffffffc0200a0c:	00002517          	auipc	a0,0x2
ffffffffc0200a10:	cdc50513          	addi	a0,a0,-804 # ffffffffc02026e8 <commands+0x4c0>
}
ffffffffc0200a14:	0141                	addi	sp,sp,16
    cprintf("  t6       0x%08x\n", gpr->t6);
ffffffffc0200a16:	ec2ff06f          	j	ffffffffc02000d8 <cprintf>

ffffffffc0200a1a <print_trapframe>:
void print_trapframe(struct trapframe *tf) {
ffffffffc0200a1a:	1141                	addi	sp,sp,-16
ffffffffc0200a1c:	e022                	sd	s0,0(sp)
    cprintf("trapframe at %p\n", tf);
ffffffffc0200a1e:	85aa                	mv	a1,a0
void print_trapframe(struct trapframe *tf) {
ffffffffc0200a20:	842a                	mv	s0,a0
    cprintf("trapframe at %p\n", tf);
ffffffffc0200a22:	00002517          	auipc	a0,0x2
ffffffffc0200a26:	cde50513          	addi	a0,a0,-802 # ffffffffc0202700 <commands+0x4d8>
void print_trapframe(struct trapframe *tf) {
ffffffffc0200a2a:	e406                	sd	ra,8(sp)
    cprintf("trapframe at %p\n", tf);
ffffffffc0200a2c:	eacff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    print_regs(&tf->gpr);
ffffffffc0200a30:	8522                	mv	a0,s0
ffffffffc0200a32:	e1bff0ef          	jal	ra,ffffffffc020084c <print_regs>
    cprintf("  status   0x%08x\n", tf->status);
ffffffffc0200a36:	10043583          	ld	a1,256(s0)
ffffffffc0200a3a:	00002517          	auipc	a0,0x2
ffffffffc0200a3e:	cde50513          	addi	a0,a0,-802 # ffffffffc0202718 <commands+0x4f0>
ffffffffc0200a42:	e96ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  epc      0x%08x\n", tf->epc);
ffffffffc0200a46:	10843583          	ld	a1,264(s0)
ffffffffc0200a4a:	00002517          	auipc	a0,0x2
ffffffffc0200a4e:	ce650513          	addi	a0,a0,-794 # ffffffffc0202730 <commands+0x508>
ffffffffc0200a52:	e86ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  badvaddr 0x%08x\n", tf->badvaddr);
ffffffffc0200a56:	11043583          	ld	a1,272(s0)
ffffffffc0200a5a:	00002517          	auipc	a0,0x2
ffffffffc0200a5e:	cee50513          	addi	a0,a0,-786 # ffffffffc0202748 <commands+0x520>
ffffffffc0200a62:	e76ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    cprintf("  cause    0x%08x\n", tf->cause);
ffffffffc0200a66:	11843583          	ld	a1,280(s0)
}
ffffffffc0200a6a:	6402                	ld	s0,0(sp)
ffffffffc0200a6c:	60a2                	ld	ra,8(sp)
    cprintf("  cause    0x%08x\n", tf->cause);
ffffffffc0200a6e:	00002517          	auipc	a0,0x2
ffffffffc0200a72:	cf250513          	addi	a0,a0,-782 # ffffffffc0202760 <commands+0x538>
}
ffffffffc0200a76:	0141                	addi	sp,sp,16
    cprintf("  cause    0x%08x\n", tf->cause);
ffffffffc0200a78:	e60ff06f          	j	ffffffffc02000d8 <cprintf>

ffffffffc0200a7c <interrupt_handler>:
#define SHUTDOWN_AFTER 10
#endif

void interrupt_handler(struct trapframe *tf) {
    const uintptr_t interrupt_bit = (uintptr_t)1 << 63;
    uintptr_t cause = tf->cause & ~interrupt_bit;
ffffffffc0200a7c:	11853583          	ld	a1,280(a0)
void interrupt_handler(struct trapframe *tf) {
ffffffffc0200a80:	1141                	addi	sp,sp,-16
ffffffffc0200a82:	e406                	sd	ra,8(sp)
    uintptr_t cause = tf->cause & ~interrupt_bit;
ffffffffc0200a84:	0586                	slli	a1,a1,0x1
void interrupt_handler(struct trapframe *tf) {
ffffffffc0200a86:	e022                	sd	s0,0(sp)

    if (cause == IRQ_S_TIMER) {
ffffffffc0200a88:	4795                	li	a5,5
    uintptr_t cause = tf->cause & ~interrupt_bit;
ffffffffc0200a8a:	8185                	srli	a1,a1,0x1
    if (cause == IRQ_S_TIMER) {
ffffffffc0200a8c:	04f58463          	beq	a1,a5,ffffffffc0200ad4 <interrupt_handler+0x58>
        [IRQ_H_EXT]   = "Hypervisor external interrupt",
        [IRQ_M_EXT]   = "Machine external interrupt",
        [IRQ_COP]     = "Coprocessor interrupt",
        [IRQ_HOST]    = "Host interrupt",
    };
    if (cause < sizeof(messages) / sizeof(messages[0]) && messages[cause]) {
ffffffffc0200a90:	47b5                	li	a5,13
ffffffffc0200a92:	842a                	mv	s0,a0
ffffffffc0200a94:	00b7eb63          	bltu	a5,a1,ffffffffc0200aaa <interrupt_handler+0x2e>
ffffffffc0200a98:	00359713          	slli	a4,a1,0x3
ffffffffc0200a9c:	00002797          	auipc	a5,0x2
ffffffffc0200aa0:	eb478793          	addi	a5,a5,-332 # ffffffffc0202950 <messages.0>
ffffffffc0200aa4:	97ba                	add	a5,a5,a4
ffffffffc0200aa6:	639c                	ld	a5,0(a5)
ffffffffc0200aa8:	ef81                	bnez	a5,ffffffffc0200ac0 <interrupt_handler+0x44>
        cprintf("%s\n", messages[cause]);
        return;
    }
    cprintf("Unknown interrupt: cause %lu\n", (unsigned long)cause);
ffffffffc0200aaa:	00002517          	auipc	a0,0x2
ffffffffc0200aae:	ce650513          	addi	a0,a0,-794 # ffffffffc0202790 <commands+0x568>
ffffffffc0200ab2:	e26ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    print_trapframe(tf);
ffffffffc0200ab6:	8522                	mv	a0,s0
}
ffffffffc0200ab8:	6402                	ld	s0,0(sp)
ffffffffc0200aba:	60a2                	ld	ra,8(sp)
ffffffffc0200abc:	0141                	addi	sp,sp,16
    print_trapframe(tf);
ffffffffc0200abe:	bfb1                	j	ffffffffc0200a1a <print_trapframe>
}
ffffffffc0200ac0:	6402                	ld	s0,0(sp)
ffffffffc0200ac2:	60a2                	ld	ra,8(sp)
        cprintf("%s\n", messages[cause]);
ffffffffc0200ac4:	85be                	mv	a1,a5
ffffffffc0200ac6:	00002517          	auipc	a0,0x2
ffffffffc0200aca:	cc250513          	addi	a0,a0,-830 # ffffffffc0202788 <commands+0x560>
}
ffffffffc0200ace:	0141                	addi	sp,sp,16
        cprintf("%s\n", messages[cause]);
ffffffffc0200ad0:	e08ff06f          	j	ffffffffc02000d8 <cprintf>
        clock_set_next_event();
ffffffffc0200ad4:	98dff0ef          	jal	ra,ffffffffc0200460 <clock_set_next_event>
        size_t count = ++ticks;
ffffffffc0200ad8:	00007717          	auipc	a4,0x7
ffffffffc0200adc:	97070713          	addi	a4,a4,-1680 # ffffffffc0207448 <ticks>
ffffffffc0200ae0:	6300                	ld	s0,0(a4)
ffffffffc0200ae2:	06400793          	li	a5,100
ffffffffc0200ae6:	00140693          	addi	a3,s0,1
ffffffffc0200aea:	02f6f7b3          	remu	a5,a3,a5
ffffffffc0200aee:	e314                	sd	a3,0(a4)
        if (count % TICK_NUM == 0) {
ffffffffc0200af0:	c789                	beqz	a5,ffffffffc0200afa <interrupt_handler+0x7e>
}
ffffffffc0200af2:	60a2                	ld	ra,8(sp)
ffffffffc0200af4:	6402                	ld	s0,0(sp)
ffffffffc0200af6:	0141                	addi	sp,sp,16
ffffffffc0200af8:	8082                	ret
    cprintf("%d ticks\n", TICK_NUM);
ffffffffc0200afa:	06400593          	li	a1,100
ffffffffc0200afe:	00002517          	auipc	a0,0x2
ffffffffc0200b02:	c7a50513          	addi	a0,a0,-902 # ffffffffc0202778 <commands+0x550>
ffffffffc0200b06:	dd2ff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
            if (count / TICK_NUM == SHUTDOWN_AFTER) {
ffffffffc0200b0a:	c1940413          	addi	s0,s0,-999
ffffffffc0200b0e:	06300793          	li	a5,99
ffffffffc0200b12:	fe87e0e3          	bltu	a5,s0,ffffffffc0200af2 <interrupt_handler+0x76>
}
ffffffffc0200b16:	6402                	ld	s0,0(sp)
ffffffffc0200b18:	60a2                	ld	ra,8(sp)
ffffffffc0200b1a:	0141                	addi	sp,sp,16
                sbi_shutdown();
ffffffffc0200b1c:	3f80106f          	j	ffffffffc0201f14 <sbi_shutdown>

ffffffffc0200b20 <exception_handler>:

void exception_handler(struct trapframe *tf) {
    switch (tf->cause) {
ffffffffc0200b20:	11853783          	ld	a5,280(a0)
void exception_handler(struct trapframe *tf) {
ffffffffc0200b24:	1141                	addi	sp,sp,-16
ffffffffc0200b26:	e022                	sd	s0,0(sp)
ffffffffc0200b28:	e406                	sd	ra,8(sp)
    switch (tf->cause) {
ffffffffc0200b2a:	4709                	li	a4,2
void exception_handler(struct trapframe *tf) {
ffffffffc0200b2c:	842a                	mv	s0,a0
    switch (tf->cause) {
ffffffffc0200b2e:	00e78963          	beq	a5,a4,ffffffffc0200b40 <exception_handler+0x20>
ffffffffc0200b32:	470d                	li	a4,3
ffffffffc0200b34:	02e78f63          	beq	a5,a4,ffffffffc0200b72 <exception_handler+0x52>
    }

    // Both instruction widths used in the lab start on a halfword boundary.
    uint16_t first_halfword = *(const volatile uint16_t *)tf->epc;
    tf->epc += (first_halfword & 3) == 3 ? 4 : 2;
}
ffffffffc0200b38:	6402                	ld	s0,0(sp)
ffffffffc0200b3a:	60a2                	ld	ra,8(sp)
ffffffffc0200b3c:	0141                	addi	sp,sp,16
        print_trapframe(tf);
ffffffffc0200b3e:	bdf1                	j	ffffffffc0200a1a <print_trapframe>
        cprintf("Illegal instruction at %p\n", (void *)tf->epc);
ffffffffc0200b40:	10853583          	ld	a1,264(a0)
ffffffffc0200b44:	00002517          	auipc	a0,0x2
ffffffffc0200b48:	c6c50513          	addi	a0,a0,-916 # ffffffffc02027b0 <commands+0x588>
ffffffffc0200b4c:	d8cff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    uint16_t first_halfword = *(const volatile uint16_t *)tf->epc;
ffffffffc0200b50:	10843783          	ld	a5,264(s0)
    tf->epc += (first_halfword & 3) == 3 ? 4 : 2;
ffffffffc0200b54:	460d                	li	a2,3
ffffffffc0200b56:	4691                	li	a3,4
    uint16_t first_halfword = *(const volatile uint16_t *)tf->epc;
ffffffffc0200b58:	0007d703          	lhu	a4,0(a5)
    tf->epc += (first_halfword & 3) == 3 ? 4 : 2;
ffffffffc0200b5c:	8b0d                	andi	a4,a4,3
ffffffffc0200b5e:	00c70363          	beq	a4,a2,ffffffffc0200b64 <exception_handler+0x44>
ffffffffc0200b62:	4689                	li	a3,2
ffffffffc0200b64:	97b6                	add	a5,a5,a3
}
ffffffffc0200b66:	60a2                	ld	ra,8(sp)
    tf->epc += (first_halfword & 3) == 3 ? 4 : 2;
ffffffffc0200b68:	10f43423          	sd	a5,264(s0)
}
ffffffffc0200b6c:	6402                	ld	s0,0(sp)
ffffffffc0200b6e:	0141                	addi	sp,sp,16
ffffffffc0200b70:	8082                	ret
        cprintf("Breakpoint at %p\n", (void *)tf->epc);
ffffffffc0200b72:	10853583          	ld	a1,264(a0)
ffffffffc0200b76:	00002517          	auipc	a0,0x2
ffffffffc0200b7a:	c5a50513          	addi	a0,a0,-934 # ffffffffc02027d0 <commands+0x5a8>
ffffffffc0200b7e:	d5aff0ef          	jal	ra,ffffffffc02000d8 <cprintf>
        break;
ffffffffc0200b82:	b7f9                	j	ffffffffc0200b50 <exception_handler+0x30>

ffffffffc0200b84 <trap>:

static inline void trap_dispatch(struct trapframe *tf) {
    if ((intptr_t)tf->cause < 0) {
ffffffffc0200b84:	11853783          	ld	a5,280(a0)
ffffffffc0200b88:	0007c363          	bltz	a5,ffffffffc0200b8e <trap+0xa>
        // interrupts
        interrupt_handler(tf);
    } else {
        // exceptions
        exception_handler(tf);
ffffffffc0200b8c:	bf51                	j	ffffffffc0200b20 <exception_handler>
        interrupt_handler(tf);
ffffffffc0200b8e:	b5fd                	j	ffffffffc0200a7c <interrupt_handler>

ffffffffc0200b90 <__alltraps>:
    .endm

    .globl __alltraps
    .align(2)
__alltraps:
    SAVE_ALL
ffffffffc0200b90:	14011073          	csrw	sscratch,sp
ffffffffc0200b94:	712d                	addi	sp,sp,-288
ffffffffc0200b96:	e002                	sd	zero,0(sp)
ffffffffc0200b98:	e406                	sd	ra,8(sp)
ffffffffc0200b9a:	ec0e                	sd	gp,24(sp)
ffffffffc0200b9c:	f012                	sd	tp,32(sp)
ffffffffc0200b9e:	f416                	sd	t0,40(sp)
ffffffffc0200ba0:	f81a                	sd	t1,48(sp)
ffffffffc0200ba2:	fc1e                	sd	t2,56(sp)
ffffffffc0200ba4:	e0a2                	sd	s0,64(sp)
ffffffffc0200ba6:	e4a6                	sd	s1,72(sp)
ffffffffc0200ba8:	e8aa                	sd	a0,80(sp)
ffffffffc0200baa:	ecae                	sd	a1,88(sp)
ffffffffc0200bac:	f0b2                	sd	a2,96(sp)
ffffffffc0200bae:	f4b6                	sd	a3,104(sp)
ffffffffc0200bb0:	f8ba                	sd	a4,112(sp)
ffffffffc0200bb2:	fcbe                	sd	a5,120(sp)
ffffffffc0200bb4:	e142                	sd	a6,128(sp)
ffffffffc0200bb6:	e546                	sd	a7,136(sp)
ffffffffc0200bb8:	e94a                	sd	s2,144(sp)
ffffffffc0200bba:	ed4e                	sd	s3,152(sp)
ffffffffc0200bbc:	f152                	sd	s4,160(sp)
ffffffffc0200bbe:	f556                	sd	s5,168(sp)
ffffffffc0200bc0:	f95a                	sd	s6,176(sp)
ffffffffc0200bc2:	fd5e                	sd	s7,184(sp)
ffffffffc0200bc4:	e1e2                	sd	s8,192(sp)
ffffffffc0200bc6:	e5e6                	sd	s9,200(sp)
ffffffffc0200bc8:	e9ea                	sd	s10,208(sp)
ffffffffc0200bca:	edee                	sd	s11,216(sp)
ffffffffc0200bcc:	f1f2                	sd	t3,224(sp)
ffffffffc0200bce:	f5f6                	sd	t4,232(sp)
ffffffffc0200bd0:	f9fa                	sd	t5,240(sp)
ffffffffc0200bd2:	fdfe                	sd	t6,248(sp)
ffffffffc0200bd4:	14001473          	csrrw	s0,sscratch,zero
ffffffffc0200bd8:	100024f3          	csrr	s1,sstatus
ffffffffc0200bdc:	14102973          	csrr	s2,sepc
ffffffffc0200be0:	143029f3          	csrr	s3,stval
ffffffffc0200be4:	14202a73          	csrr	s4,scause
ffffffffc0200be8:	e822                	sd	s0,16(sp)
ffffffffc0200bea:	e226                	sd	s1,256(sp)
ffffffffc0200bec:	e64a                	sd	s2,264(sp)
ffffffffc0200bee:	ea4e                	sd	s3,272(sp)
ffffffffc0200bf0:	ee52                	sd	s4,280(sp)

    #lab3 function1 2413115
    mv s0, sp
ffffffffc0200bf2:	840a                	mv	s0,sp
    mv a0, sp
ffffffffc0200bf4:	850a                	mv	a0,sp
    call trap
ffffffffc0200bf6:	f8fff0ef          	jal	ra,ffffffffc0200b84 <trap>
    mv sp, s0
ffffffffc0200bfa:	8122                	mv	sp,s0

ffffffffc0200bfc <__trapret>:
    # sp should be the same as before "jal trap"

    .globl __trapret
__trapret:
    RESTORE_ALL
ffffffffc0200bfc:	6412                	ld	s0,256(sp)
ffffffffc0200bfe:	64b2                	ld	s1,264(sp)
ffffffffc0200c00:	10041073          	csrw	sstatus,s0
ffffffffc0200c04:	14149073          	csrw	sepc,s1
ffffffffc0200c08:	60a2                	ld	ra,8(sp)
ffffffffc0200c0a:	61e2                	ld	gp,24(sp)
ffffffffc0200c0c:	7202                	ld	tp,32(sp)
ffffffffc0200c0e:	72a2                	ld	t0,40(sp)
ffffffffc0200c10:	7342                	ld	t1,48(sp)
ffffffffc0200c12:	73e2                	ld	t2,56(sp)
ffffffffc0200c14:	6406                	ld	s0,64(sp)
ffffffffc0200c16:	64a6                	ld	s1,72(sp)
ffffffffc0200c18:	6546                	ld	a0,80(sp)
ffffffffc0200c1a:	65e6                	ld	a1,88(sp)
ffffffffc0200c1c:	7606                	ld	a2,96(sp)
ffffffffc0200c1e:	76a6                	ld	a3,104(sp)
ffffffffc0200c20:	7746                	ld	a4,112(sp)
ffffffffc0200c22:	77e6                	ld	a5,120(sp)
ffffffffc0200c24:	680a                	ld	a6,128(sp)
ffffffffc0200c26:	68aa                	ld	a7,136(sp)
ffffffffc0200c28:	694a                	ld	s2,144(sp)
ffffffffc0200c2a:	69ea                	ld	s3,152(sp)
ffffffffc0200c2c:	7a0a                	ld	s4,160(sp)
ffffffffc0200c2e:	7aaa                	ld	s5,168(sp)
ffffffffc0200c30:	7b4a                	ld	s6,176(sp)
ffffffffc0200c32:	7bea                	ld	s7,184(sp)
ffffffffc0200c34:	6c0e                	ld	s8,192(sp)
ffffffffc0200c36:	6cae                	ld	s9,200(sp)
ffffffffc0200c38:	6d4e                	ld	s10,208(sp)
ffffffffc0200c3a:	6dee                	ld	s11,216(sp)
ffffffffc0200c3c:	7e0e                	ld	t3,224(sp)
ffffffffc0200c3e:	7eae                	ld	t4,232(sp)
ffffffffc0200c40:	7f4e                	ld	t5,240(sp)
ffffffffc0200c42:	7fee                	ld	t6,248(sp)
ffffffffc0200c44:	6142                	ld	sp,16(sp)
    # return from supervisor call
    sret
ffffffffc0200c46:	10200073          	sret

ffffffffc0200c4a <default_init>:
 * list_init - initialize a new entry
 * @elm:        new entry to be initialized
 * */
static inline void
list_init(list_entry_t *elm) {
    elm->prev = elm->next = elm;
ffffffffc0200c4a:	00006797          	auipc	a5,0x6
ffffffffc0200c4e:	3de78793          	addi	a5,a5,990 # ffffffffc0207028 <free_area>
ffffffffc0200c52:	e79c                	sd	a5,8(a5)
ffffffffc0200c54:	e39c                	sd	a5,0(a5)
#define nr_free (free_area.nr_free)

static void
default_init(void) {
    list_init(&free_list);
    nr_free = 0;
ffffffffc0200c56:	0007a823          	sw	zero,16(a5)
}
ffffffffc0200c5a:	8082                	ret

ffffffffc0200c5c <default_nr_free_pages>:
}

static size_t
default_nr_free_pages(void) {
    return nr_free;
}
ffffffffc0200c5c:	00006517          	auipc	a0,0x6
ffffffffc0200c60:	3dc56503          	lwu	a0,988(a0) # ffffffffc0207038 <free_area+0x10>
ffffffffc0200c64:	8082                	ret

ffffffffc0200c66 <default_check>:
}

// LAB2: below code is used to check the first fit allocation algorithm (your EXERCISE 1) 
// NOTICE: You SHOULD NOT CHANGE basic_check, default_check functions!
static void
default_check(void) {
ffffffffc0200c66:	715d                	addi	sp,sp,-80
ffffffffc0200c68:	e0a2                	sd	s0,64(sp)
 * list_next - get the next entry
 * @listelm:    the list head
 **/
static inline list_entry_t *
list_next(list_entry_t *listelm) {
    return listelm->next;
ffffffffc0200c6a:	00006417          	auipc	s0,0x6
ffffffffc0200c6e:	3be40413          	addi	s0,s0,958 # ffffffffc0207028 <free_area>
ffffffffc0200c72:	641c                	ld	a5,8(s0)
ffffffffc0200c74:	e486                	sd	ra,72(sp)
ffffffffc0200c76:	fc26                	sd	s1,56(sp)
ffffffffc0200c78:	f84a                	sd	s2,48(sp)
ffffffffc0200c7a:	f44e                	sd	s3,40(sp)
ffffffffc0200c7c:	f052                	sd	s4,32(sp)
ffffffffc0200c7e:	ec56                	sd	s5,24(sp)
ffffffffc0200c80:	e85a                	sd	s6,16(sp)
ffffffffc0200c82:	e45e                	sd	s7,8(sp)
ffffffffc0200c84:	e062                	sd	s8,0(sp)
    int count = 0, total = 0;
    list_entry_t *le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200c86:	2c878763          	beq	a5,s0,ffffffffc0200f54 <default_check+0x2ee>
    int count = 0, total = 0;
ffffffffc0200c8a:	4481                	li	s1,0
ffffffffc0200c8c:	4901                	li	s2,0
 * test_bit - Determine whether a bit is set
 * @nr:     the bit to test
 * @addr:   the address to count from
 * */
static inline bool test_bit(int nr, volatile void *addr) {
    return (((*(volatile unsigned long *)addr) >> nr) & 1);
ffffffffc0200c8e:	ff07b703          	ld	a4,-16(a5)
        struct Page *p = le2page(le, page_link);
        assert(PageProperty(p));
ffffffffc0200c92:	8b09                	andi	a4,a4,2
ffffffffc0200c94:	2c070463          	beqz	a4,ffffffffc0200f5c <default_check+0x2f6>
        count ++, total += p->property;
ffffffffc0200c98:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200c9c:	679c                	ld	a5,8(a5)
ffffffffc0200c9e:	2905                	addiw	s2,s2,1
ffffffffc0200ca0:	9cb9                	addw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200ca2:	fe8796e3          	bne	a5,s0,ffffffffc0200c8e <default_check+0x28>
    }
    assert(total == nr_free_pages());
ffffffffc0200ca6:	89a6                	mv	s3,s1
ffffffffc0200ca8:	2f9000ef          	jal	ra,ffffffffc02017a0 <nr_free_pages>
ffffffffc0200cac:	71351863          	bne	a0,s3,ffffffffc02013bc <default_check+0x756>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200cb0:	4505                	li	a0,1
ffffffffc0200cb2:	271000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200cb6:	8a2a                	mv	s4,a0
ffffffffc0200cb8:	44050263          	beqz	a0,ffffffffc02010fc <default_check+0x496>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200cbc:	4505                	li	a0,1
ffffffffc0200cbe:	265000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200cc2:	89aa                	mv	s3,a0
ffffffffc0200cc4:	70050c63          	beqz	a0,ffffffffc02013dc <default_check+0x776>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200cc8:	4505                	li	a0,1
ffffffffc0200cca:	259000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200cce:	8aaa                	mv	s5,a0
ffffffffc0200cd0:	4a050663          	beqz	a0,ffffffffc020117c <default_check+0x516>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200cd4:	2b3a0463          	beq	s4,s3,ffffffffc0200f7c <default_check+0x316>
ffffffffc0200cd8:	2aaa0263          	beq	s4,a0,ffffffffc0200f7c <default_check+0x316>
ffffffffc0200cdc:	2aa98063          	beq	s3,a0,ffffffffc0200f7c <default_check+0x316>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200ce0:	000a2783          	lw	a5,0(s4)
ffffffffc0200ce4:	2a079c63          	bnez	a5,ffffffffc0200f9c <default_check+0x336>
ffffffffc0200ce8:	0009a783          	lw	a5,0(s3)
ffffffffc0200cec:	2a079863          	bnez	a5,ffffffffc0200f9c <default_check+0x336>
ffffffffc0200cf0:	411c                	lw	a5,0(a0)
ffffffffc0200cf2:	2a079563          	bnez	a5,ffffffffc0200f9c <default_check+0x336>
extern struct Page *pages;
extern size_t npage;
extern const size_t nbase;
extern uint64_t va_pa_offset;

static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200cf6:	00006797          	auipc	a5,0x6
ffffffffc0200cfa:	7727b783          	ld	a5,1906(a5) # ffffffffc0207468 <pages>
ffffffffc0200cfe:	40fa0733          	sub	a4,s4,a5
ffffffffc0200d02:	870d                	srai	a4,a4,0x3
ffffffffc0200d04:	00002597          	auipc	a1,0x2
ffffffffc0200d08:	4c45b583          	ld	a1,1220(a1) # ffffffffc02031c8 <error_string+0x38>
ffffffffc0200d0c:	02b70733          	mul	a4,a4,a1
ffffffffc0200d10:	00002617          	auipc	a2,0x2
ffffffffc0200d14:	4c863603          	ld	a2,1224(a2) # ffffffffc02031d8 <nbase>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200d18:	00006697          	auipc	a3,0x6
ffffffffc0200d1c:	7486b683          	ld	a3,1864(a3) # ffffffffc0207460 <npage>
ffffffffc0200d20:	06b2                	slli	a3,a3,0xc
ffffffffc0200d22:	9732                	add	a4,a4,a2

static inline uintptr_t page2pa(struct Page *page) {
    return page2ppn(page) << PGSHIFT;
ffffffffc0200d24:	0732                	slli	a4,a4,0xc
ffffffffc0200d26:	28d77b63          	bgeu	a4,a3,ffffffffc0200fbc <default_check+0x356>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200d2a:	40f98733          	sub	a4,s3,a5
ffffffffc0200d2e:	870d                	srai	a4,a4,0x3
ffffffffc0200d30:	02b70733          	mul	a4,a4,a1
ffffffffc0200d34:	9732                	add	a4,a4,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200d36:	0732                	slli	a4,a4,0xc
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc0200d38:	4cd77263          	bgeu	a4,a3,ffffffffc02011fc <default_check+0x596>
static inline ppn_t page2ppn(struct Page *page) { return page - pages + nbase; }
ffffffffc0200d3c:	40f507b3          	sub	a5,a0,a5
ffffffffc0200d40:	878d                	srai	a5,a5,0x3
ffffffffc0200d42:	02b787b3          	mul	a5,a5,a1
ffffffffc0200d46:	97b2                	add	a5,a5,a2
    return page2ppn(page) << PGSHIFT;
ffffffffc0200d48:	07b2                	slli	a5,a5,0xc
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc0200d4a:	30d7f963          	bgeu	a5,a3,ffffffffc020105c <default_check+0x3f6>
    assert(alloc_page() == NULL);
ffffffffc0200d4e:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200d50:	00043c03          	ld	s8,0(s0)
ffffffffc0200d54:	00843b83          	ld	s7,8(s0)
    unsigned int nr_free_store = nr_free;
ffffffffc0200d58:	01042b03          	lw	s6,16(s0)
    elm->prev = elm->next = elm;
ffffffffc0200d5c:	e400                	sd	s0,8(s0)
ffffffffc0200d5e:	e000                	sd	s0,0(s0)
    nr_free = 0;
ffffffffc0200d60:	00006797          	auipc	a5,0x6
ffffffffc0200d64:	2c07ac23          	sw	zero,728(a5) # ffffffffc0207038 <free_area+0x10>
    assert(alloc_page() == NULL);
ffffffffc0200d68:	1bb000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200d6c:	2c051863          	bnez	a0,ffffffffc020103c <default_check+0x3d6>
    free_page(p0);
ffffffffc0200d70:	4585                	li	a1,1
ffffffffc0200d72:	8552                	mv	a0,s4
ffffffffc0200d74:	1ed000ef          	jal	ra,ffffffffc0201760 <free_pages>
    free_page(p1);
ffffffffc0200d78:	4585                	li	a1,1
ffffffffc0200d7a:	854e                	mv	a0,s3
ffffffffc0200d7c:	1e5000ef          	jal	ra,ffffffffc0201760 <free_pages>
    free_page(p2);
ffffffffc0200d80:	4585                	li	a1,1
ffffffffc0200d82:	8556                	mv	a0,s5
ffffffffc0200d84:	1dd000ef          	jal	ra,ffffffffc0201760 <free_pages>
    assert(nr_free == 3);
ffffffffc0200d88:	4818                	lw	a4,16(s0)
ffffffffc0200d8a:	478d                	li	a5,3
ffffffffc0200d8c:	28f71863          	bne	a4,a5,ffffffffc020101c <default_check+0x3b6>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200d90:	4505                	li	a0,1
ffffffffc0200d92:	191000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200d96:	89aa                	mv	s3,a0
ffffffffc0200d98:	26050263          	beqz	a0,ffffffffc0200ffc <default_check+0x396>
    assert((p1 = alloc_page()) != NULL);
ffffffffc0200d9c:	4505                	li	a0,1
ffffffffc0200d9e:	185000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200da2:	8aaa                	mv	s5,a0
ffffffffc0200da4:	3a050c63          	beqz	a0,ffffffffc020115c <default_check+0x4f6>
    assert((p2 = alloc_page()) != NULL);
ffffffffc0200da8:	4505                	li	a0,1
ffffffffc0200daa:	179000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200dae:	8a2a                	mv	s4,a0
ffffffffc0200db0:	38050663          	beqz	a0,ffffffffc020113c <default_check+0x4d6>
    assert(alloc_page() == NULL);
ffffffffc0200db4:	4505                	li	a0,1
ffffffffc0200db6:	16d000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200dba:	36051163          	bnez	a0,ffffffffc020111c <default_check+0x4b6>
    free_page(p0);
ffffffffc0200dbe:	4585                	li	a1,1
ffffffffc0200dc0:	854e                	mv	a0,s3
ffffffffc0200dc2:	19f000ef          	jal	ra,ffffffffc0201760 <free_pages>
    assert(!list_empty(&free_list));
ffffffffc0200dc6:	641c                	ld	a5,8(s0)
ffffffffc0200dc8:	20878a63          	beq	a5,s0,ffffffffc0200fdc <default_check+0x376>
    assert((p = alloc_page()) == p0);
ffffffffc0200dcc:	4505                	li	a0,1
ffffffffc0200dce:	155000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200dd2:	30a99563          	bne	s3,a0,ffffffffc02010dc <default_check+0x476>
    assert(alloc_page() == NULL);
ffffffffc0200dd6:	4505                	li	a0,1
ffffffffc0200dd8:	14b000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200ddc:	2e051063          	bnez	a0,ffffffffc02010bc <default_check+0x456>
    assert(nr_free == 0);
ffffffffc0200de0:	481c                	lw	a5,16(s0)
ffffffffc0200de2:	2a079d63          	bnez	a5,ffffffffc020109c <default_check+0x436>
    free_page(p);
ffffffffc0200de6:	854e                	mv	a0,s3
ffffffffc0200de8:	4585                	li	a1,1
    free_list = free_list_store;
ffffffffc0200dea:	01843023          	sd	s8,0(s0)
ffffffffc0200dee:	01743423          	sd	s7,8(s0)
    nr_free = nr_free_store;
ffffffffc0200df2:	01642823          	sw	s6,16(s0)
    free_page(p);
ffffffffc0200df6:	16b000ef          	jal	ra,ffffffffc0201760 <free_pages>
    free_page(p1);
ffffffffc0200dfa:	4585                	li	a1,1
ffffffffc0200dfc:	8556                	mv	a0,s5
ffffffffc0200dfe:	163000ef          	jal	ra,ffffffffc0201760 <free_pages>
    free_page(p2);
ffffffffc0200e02:	4585                	li	a1,1
ffffffffc0200e04:	8552                	mv	a0,s4
ffffffffc0200e06:	15b000ef          	jal	ra,ffffffffc0201760 <free_pages>

    basic_check();

    struct Page *p0 = alloc_pages(5), *p1, *p2;
ffffffffc0200e0a:	4515                	li	a0,5
ffffffffc0200e0c:	117000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200e10:	89aa                	mv	s3,a0
    assert(p0 != NULL);
ffffffffc0200e12:	26050563          	beqz	a0,ffffffffc020107c <default_check+0x416>
ffffffffc0200e16:	651c                	ld	a5,8(a0)
ffffffffc0200e18:	8385                	srli	a5,a5,0x1
    assert(!PageProperty(p0));
ffffffffc0200e1a:	8b85                	andi	a5,a5,1
ffffffffc0200e1c:	54079063          	bnez	a5,ffffffffc020135c <default_check+0x6f6>

    list_entry_t free_list_store = free_list;
    list_init(&free_list);
    assert(list_empty(&free_list));
    assert(alloc_page() == NULL);
ffffffffc0200e20:	4505                	li	a0,1
    list_entry_t free_list_store = free_list;
ffffffffc0200e22:	00043b03          	ld	s6,0(s0)
ffffffffc0200e26:	00843a83          	ld	s5,8(s0)
ffffffffc0200e2a:	e000                	sd	s0,0(s0)
ffffffffc0200e2c:	e400                	sd	s0,8(s0)
    assert(alloc_page() == NULL);
ffffffffc0200e2e:	0f5000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200e32:	50051563          	bnez	a0,ffffffffc020133c <default_check+0x6d6>

    unsigned int nr_free_store = nr_free;
    nr_free = 0;

    free_pages(p0 + 2, 3);
ffffffffc0200e36:	05098a13          	addi	s4,s3,80
ffffffffc0200e3a:	8552                	mv	a0,s4
ffffffffc0200e3c:	458d                	li	a1,3
    unsigned int nr_free_store = nr_free;
ffffffffc0200e3e:	01042b83          	lw	s7,16(s0)
    nr_free = 0;
ffffffffc0200e42:	00006797          	auipc	a5,0x6
ffffffffc0200e46:	1e07ab23          	sw	zero,502(a5) # ffffffffc0207038 <free_area+0x10>
    free_pages(p0 + 2, 3);
ffffffffc0200e4a:	117000ef          	jal	ra,ffffffffc0201760 <free_pages>
    assert(alloc_pages(4) == NULL);
ffffffffc0200e4e:	4511                	li	a0,4
ffffffffc0200e50:	0d3000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200e54:	4c051463          	bnez	a0,ffffffffc020131c <default_check+0x6b6>
ffffffffc0200e58:	0589b783          	ld	a5,88(s3)
ffffffffc0200e5c:	8385                	srli	a5,a5,0x1
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
ffffffffc0200e5e:	8b85                	andi	a5,a5,1
ffffffffc0200e60:	48078e63          	beqz	a5,ffffffffc02012fc <default_check+0x696>
ffffffffc0200e64:	0609a703          	lw	a4,96(s3)
ffffffffc0200e68:	478d                	li	a5,3
ffffffffc0200e6a:	48f71963          	bne	a4,a5,ffffffffc02012fc <default_check+0x696>
    assert((p1 = alloc_pages(3)) != NULL);
ffffffffc0200e6e:	450d                	li	a0,3
ffffffffc0200e70:	0b3000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200e74:	8c2a                	mv	s8,a0
ffffffffc0200e76:	46050363          	beqz	a0,ffffffffc02012dc <default_check+0x676>
    assert(alloc_page() == NULL);
ffffffffc0200e7a:	4505                	li	a0,1
ffffffffc0200e7c:	0a7000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200e80:	42051e63          	bnez	a0,ffffffffc02012bc <default_check+0x656>
    assert(p0 + 2 == p1);
ffffffffc0200e84:	418a1c63          	bne	s4,s8,ffffffffc020129c <default_check+0x636>

    p2 = p0 + 1;
    free_page(p0);
ffffffffc0200e88:	4585                	li	a1,1
ffffffffc0200e8a:	854e                	mv	a0,s3
ffffffffc0200e8c:	0d5000ef          	jal	ra,ffffffffc0201760 <free_pages>
    free_pages(p1, 3);
ffffffffc0200e90:	458d                	li	a1,3
ffffffffc0200e92:	8552                	mv	a0,s4
ffffffffc0200e94:	0cd000ef          	jal	ra,ffffffffc0201760 <free_pages>
ffffffffc0200e98:	0089b783          	ld	a5,8(s3)
    p2 = p0 + 1;
ffffffffc0200e9c:	02898c13          	addi	s8,s3,40
ffffffffc0200ea0:	8385                	srli	a5,a5,0x1
    assert(PageProperty(p0) && p0->property == 1);
ffffffffc0200ea2:	8b85                	andi	a5,a5,1
ffffffffc0200ea4:	3c078c63          	beqz	a5,ffffffffc020127c <default_check+0x616>
ffffffffc0200ea8:	0109a703          	lw	a4,16(s3)
ffffffffc0200eac:	4785                	li	a5,1
ffffffffc0200eae:	3cf71763          	bne	a4,a5,ffffffffc020127c <default_check+0x616>
ffffffffc0200eb2:	008a3783          	ld	a5,8(s4)
ffffffffc0200eb6:	8385                	srli	a5,a5,0x1
    assert(PageProperty(p1) && p1->property == 3);
ffffffffc0200eb8:	8b85                	andi	a5,a5,1
ffffffffc0200eba:	3a078163          	beqz	a5,ffffffffc020125c <default_check+0x5f6>
ffffffffc0200ebe:	010a2703          	lw	a4,16(s4)
ffffffffc0200ec2:	478d                	li	a5,3
ffffffffc0200ec4:	38f71c63          	bne	a4,a5,ffffffffc020125c <default_check+0x5f6>

    assert((p0 = alloc_page()) == p2 - 1);
ffffffffc0200ec8:	4505                	li	a0,1
ffffffffc0200eca:	059000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200ece:	36a99763          	bne	s3,a0,ffffffffc020123c <default_check+0x5d6>
    free_page(p0);
ffffffffc0200ed2:	4585                	li	a1,1
ffffffffc0200ed4:	08d000ef          	jal	ra,ffffffffc0201760 <free_pages>
    assert((p0 = alloc_pages(2)) == p2 + 1);
ffffffffc0200ed8:	4509                	li	a0,2
ffffffffc0200eda:	049000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200ede:	32aa1f63          	bne	s4,a0,ffffffffc020121c <default_check+0x5b6>

    free_pages(p0, 2);
ffffffffc0200ee2:	4589                	li	a1,2
ffffffffc0200ee4:	07d000ef          	jal	ra,ffffffffc0201760 <free_pages>
    free_page(p2);
ffffffffc0200ee8:	4585                	li	a1,1
ffffffffc0200eea:	8562                	mv	a0,s8
ffffffffc0200eec:	075000ef          	jal	ra,ffffffffc0201760 <free_pages>

    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc0200ef0:	4515                	li	a0,5
ffffffffc0200ef2:	031000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200ef6:	89aa                	mv	s3,a0
ffffffffc0200ef8:	48050263          	beqz	a0,ffffffffc020137c <default_check+0x716>
    assert(alloc_page() == NULL);
ffffffffc0200efc:	4505                	li	a0,1
ffffffffc0200efe:	025000ef          	jal	ra,ffffffffc0201722 <alloc_pages>
ffffffffc0200f02:	2c051d63          	bnez	a0,ffffffffc02011dc <default_check+0x576>

    assert(nr_free == 0);
ffffffffc0200f06:	481c                	lw	a5,16(s0)
ffffffffc0200f08:	2a079a63          	bnez	a5,ffffffffc02011bc <default_check+0x556>
    nr_free = nr_free_store;

    free_list = free_list_store;
    free_pages(p0, 5);
ffffffffc0200f0c:	4595                	li	a1,5
ffffffffc0200f0e:	854e                	mv	a0,s3
    nr_free = nr_free_store;
ffffffffc0200f10:	01742823          	sw	s7,16(s0)
    free_list = free_list_store;
ffffffffc0200f14:	01643023          	sd	s6,0(s0)
ffffffffc0200f18:	01543423          	sd	s5,8(s0)
    free_pages(p0, 5);
ffffffffc0200f1c:	045000ef          	jal	ra,ffffffffc0201760 <free_pages>
    return listelm->next;
ffffffffc0200f20:	641c                	ld	a5,8(s0)

    le = &free_list;
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200f22:	00878963          	beq	a5,s0,ffffffffc0200f34 <default_check+0x2ce>
        struct Page *p = le2page(le, page_link);
        count --, total -= p->property;
ffffffffc0200f26:	ff87a703          	lw	a4,-8(a5)
ffffffffc0200f2a:	679c                	ld	a5,8(a5)
ffffffffc0200f2c:	397d                	addiw	s2,s2,-1
ffffffffc0200f2e:	9c99                	subw	s1,s1,a4
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200f30:	fe879be3          	bne	a5,s0,ffffffffc0200f26 <default_check+0x2c0>
    }
    assert(count == 0);
ffffffffc0200f34:	26091463          	bnez	s2,ffffffffc020119c <default_check+0x536>
    assert(total == 0);
ffffffffc0200f38:	46049263          	bnez	s1,ffffffffc020139c <default_check+0x736>
}
ffffffffc0200f3c:	60a6                	ld	ra,72(sp)
ffffffffc0200f3e:	6406                	ld	s0,64(sp)
ffffffffc0200f40:	74e2                	ld	s1,56(sp)
ffffffffc0200f42:	7942                	ld	s2,48(sp)
ffffffffc0200f44:	79a2                	ld	s3,40(sp)
ffffffffc0200f46:	7a02                	ld	s4,32(sp)
ffffffffc0200f48:	6ae2                	ld	s5,24(sp)
ffffffffc0200f4a:	6b42                	ld	s6,16(sp)
ffffffffc0200f4c:	6ba2                	ld	s7,8(sp)
ffffffffc0200f4e:	6c02                	ld	s8,0(sp)
ffffffffc0200f50:	6161                	addi	sp,sp,80
ffffffffc0200f52:	8082                	ret
    while ((le = list_next(le)) != &free_list) {
ffffffffc0200f54:	4981                	li	s3,0
    int count = 0, total = 0;
ffffffffc0200f56:	4481                	li	s1,0
ffffffffc0200f58:	4901                	li	s2,0
ffffffffc0200f5a:	b3b9                	j	ffffffffc0200ca8 <default_check+0x42>
        assert(PageProperty(p));
ffffffffc0200f5c:	00002697          	auipc	a3,0x2
ffffffffc0200f60:	a6468693          	addi	a3,a3,-1436 # ffffffffc02029c0 <messages.0+0x70>
ffffffffc0200f64:	00002617          	auipc	a2,0x2
ffffffffc0200f68:	a6c60613          	addi	a2,a2,-1428 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc0200f6c:	0e800593          	li	a1,232
ffffffffc0200f70:	00002517          	auipc	a0,0x2
ffffffffc0200f74:	a7850513          	addi	a0,a0,-1416 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0200f78:	c5aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(p0 != p1 && p0 != p2 && p1 != p2);
ffffffffc0200f7c:	00002697          	auipc	a3,0x2
ffffffffc0200f80:	b0468693          	addi	a3,a3,-1276 # ffffffffc0202a80 <messages.0+0x130>
ffffffffc0200f84:	00002617          	auipc	a2,0x2
ffffffffc0200f88:	a4c60613          	addi	a2,a2,-1460 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc0200f8c:	0b500593          	li	a1,181
ffffffffc0200f90:	00002517          	auipc	a0,0x2
ffffffffc0200f94:	a5850513          	addi	a0,a0,-1448 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0200f98:	c3aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(page_ref(p0) == 0 && page_ref(p1) == 0 && page_ref(p2) == 0);
ffffffffc0200f9c:	00002697          	auipc	a3,0x2
ffffffffc0200fa0:	b0c68693          	addi	a3,a3,-1268 # ffffffffc0202aa8 <messages.0+0x158>
ffffffffc0200fa4:	00002617          	auipc	a2,0x2
ffffffffc0200fa8:	a2c60613          	addi	a2,a2,-1492 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc0200fac:	0b600593          	li	a1,182
ffffffffc0200fb0:	00002517          	auipc	a0,0x2
ffffffffc0200fb4:	a3850513          	addi	a0,a0,-1480 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0200fb8:	c1aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(page2pa(p0) < npage * PGSIZE);
ffffffffc0200fbc:	00002697          	auipc	a3,0x2
ffffffffc0200fc0:	b2c68693          	addi	a3,a3,-1236 # ffffffffc0202ae8 <messages.0+0x198>
ffffffffc0200fc4:	00002617          	auipc	a2,0x2
ffffffffc0200fc8:	a0c60613          	addi	a2,a2,-1524 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc0200fcc:	0b800593          	li	a1,184
ffffffffc0200fd0:	00002517          	auipc	a0,0x2
ffffffffc0200fd4:	a1850513          	addi	a0,a0,-1512 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0200fd8:	bfaff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(!list_empty(&free_list));
ffffffffc0200fdc:	00002697          	auipc	a3,0x2
ffffffffc0200fe0:	b9468693          	addi	a3,a3,-1132 # ffffffffc0202b70 <messages.0+0x220>
ffffffffc0200fe4:	00002617          	auipc	a2,0x2
ffffffffc0200fe8:	9ec60613          	addi	a2,a2,-1556 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc0200fec:	0d100593          	li	a1,209
ffffffffc0200ff0:	00002517          	auipc	a0,0x2
ffffffffc0200ff4:	9f850513          	addi	a0,a0,-1544 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0200ff8:	bdaff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc0200ffc:	00002697          	auipc	a3,0x2
ffffffffc0201000:	a2468693          	addi	a3,a3,-1500 # ffffffffc0202a20 <messages.0+0xd0>
ffffffffc0201004:	00002617          	auipc	a2,0x2
ffffffffc0201008:	9cc60613          	addi	a2,a2,-1588 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020100c:	0ca00593          	li	a1,202
ffffffffc0201010:	00002517          	auipc	a0,0x2
ffffffffc0201014:	9d850513          	addi	a0,a0,-1576 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201018:	bbaff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(nr_free == 3);
ffffffffc020101c:	00002697          	auipc	a3,0x2
ffffffffc0201020:	b4468693          	addi	a3,a3,-1212 # ffffffffc0202b60 <messages.0+0x210>
ffffffffc0201024:	00002617          	auipc	a2,0x2
ffffffffc0201028:	9ac60613          	addi	a2,a2,-1620 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020102c:	0c800593          	li	a1,200
ffffffffc0201030:	00002517          	auipc	a0,0x2
ffffffffc0201034:	9b850513          	addi	a0,a0,-1608 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201038:	b9aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc020103c:	00002697          	auipc	a3,0x2
ffffffffc0201040:	b0c68693          	addi	a3,a3,-1268 # ffffffffc0202b48 <messages.0+0x1f8>
ffffffffc0201044:	00002617          	auipc	a2,0x2
ffffffffc0201048:	98c60613          	addi	a2,a2,-1652 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020104c:	0c300593          	li	a1,195
ffffffffc0201050:	00002517          	auipc	a0,0x2
ffffffffc0201054:	99850513          	addi	a0,a0,-1640 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201058:	b7aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(page2pa(p2) < npage * PGSIZE);
ffffffffc020105c:	00002697          	auipc	a3,0x2
ffffffffc0201060:	acc68693          	addi	a3,a3,-1332 # ffffffffc0202b28 <messages.0+0x1d8>
ffffffffc0201064:	00002617          	auipc	a2,0x2
ffffffffc0201068:	96c60613          	addi	a2,a2,-1684 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020106c:	0ba00593          	li	a1,186
ffffffffc0201070:	00002517          	auipc	a0,0x2
ffffffffc0201074:	97850513          	addi	a0,a0,-1672 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201078:	b5aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(p0 != NULL);
ffffffffc020107c:	00002697          	auipc	a3,0x2
ffffffffc0201080:	b3c68693          	addi	a3,a3,-1220 # ffffffffc0202bb8 <messages.0+0x268>
ffffffffc0201084:	00002617          	auipc	a2,0x2
ffffffffc0201088:	94c60613          	addi	a2,a2,-1716 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020108c:	0f000593          	li	a1,240
ffffffffc0201090:	00002517          	auipc	a0,0x2
ffffffffc0201094:	95850513          	addi	a0,a0,-1704 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201098:	b3aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(nr_free == 0);
ffffffffc020109c:	00002697          	auipc	a3,0x2
ffffffffc02010a0:	b0c68693          	addi	a3,a3,-1268 # ffffffffc0202ba8 <messages.0+0x258>
ffffffffc02010a4:	00002617          	auipc	a2,0x2
ffffffffc02010a8:	92c60613          	addi	a2,a2,-1748 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02010ac:	0d700593          	li	a1,215
ffffffffc02010b0:	00002517          	auipc	a0,0x2
ffffffffc02010b4:	93850513          	addi	a0,a0,-1736 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02010b8:	b1aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc02010bc:	00002697          	auipc	a3,0x2
ffffffffc02010c0:	a8c68693          	addi	a3,a3,-1396 # ffffffffc0202b48 <messages.0+0x1f8>
ffffffffc02010c4:	00002617          	auipc	a2,0x2
ffffffffc02010c8:	90c60613          	addi	a2,a2,-1780 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02010cc:	0d500593          	li	a1,213
ffffffffc02010d0:	00002517          	auipc	a0,0x2
ffffffffc02010d4:	91850513          	addi	a0,a0,-1768 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02010d8:	afaff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p = alloc_page()) == p0);
ffffffffc02010dc:	00002697          	auipc	a3,0x2
ffffffffc02010e0:	aac68693          	addi	a3,a3,-1364 # ffffffffc0202b88 <messages.0+0x238>
ffffffffc02010e4:	00002617          	auipc	a2,0x2
ffffffffc02010e8:	8ec60613          	addi	a2,a2,-1812 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02010ec:	0d400593          	li	a1,212
ffffffffc02010f0:	00002517          	auipc	a0,0x2
ffffffffc02010f4:	8f850513          	addi	a0,a0,-1800 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02010f8:	adaff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p0 = alloc_page()) != NULL);
ffffffffc02010fc:	00002697          	auipc	a3,0x2
ffffffffc0201100:	92468693          	addi	a3,a3,-1756 # ffffffffc0202a20 <messages.0+0xd0>
ffffffffc0201104:	00002617          	auipc	a2,0x2
ffffffffc0201108:	8cc60613          	addi	a2,a2,-1844 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020110c:	0b100593          	li	a1,177
ffffffffc0201110:	00002517          	auipc	a0,0x2
ffffffffc0201114:	8d850513          	addi	a0,a0,-1832 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201118:	abaff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc020111c:	00002697          	auipc	a3,0x2
ffffffffc0201120:	a2c68693          	addi	a3,a3,-1492 # ffffffffc0202b48 <messages.0+0x1f8>
ffffffffc0201124:	00002617          	auipc	a2,0x2
ffffffffc0201128:	8ac60613          	addi	a2,a2,-1876 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020112c:	0ce00593          	li	a1,206
ffffffffc0201130:	00002517          	auipc	a0,0x2
ffffffffc0201134:	8b850513          	addi	a0,a0,-1864 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201138:	a9aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc020113c:	00002697          	auipc	a3,0x2
ffffffffc0201140:	92468693          	addi	a3,a3,-1756 # ffffffffc0202a60 <messages.0+0x110>
ffffffffc0201144:	00002617          	auipc	a2,0x2
ffffffffc0201148:	88c60613          	addi	a2,a2,-1908 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020114c:	0cc00593          	li	a1,204
ffffffffc0201150:	00002517          	auipc	a0,0x2
ffffffffc0201154:	89850513          	addi	a0,a0,-1896 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201158:	a7aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc020115c:	00002697          	auipc	a3,0x2
ffffffffc0201160:	8e468693          	addi	a3,a3,-1820 # ffffffffc0202a40 <messages.0+0xf0>
ffffffffc0201164:	00002617          	auipc	a2,0x2
ffffffffc0201168:	86c60613          	addi	a2,a2,-1940 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020116c:	0cb00593          	li	a1,203
ffffffffc0201170:	00002517          	auipc	a0,0x2
ffffffffc0201174:	87850513          	addi	a0,a0,-1928 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201178:	a5aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p2 = alloc_page()) != NULL);
ffffffffc020117c:	00002697          	auipc	a3,0x2
ffffffffc0201180:	8e468693          	addi	a3,a3,-1820 # ffffffffc0202a60 <messages.0+0x110>
ffffffffc0201184:	00002617          	auipc	a2,0x2
ffffffffc0201188:	84c60613          	addi	a2,a2,-1972 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020118c:	0b300593          	li	a1,179
ffffffffc0201190:	00002517          	auipc	a0,0x2
ffffffffc0201194:	85850513          	addi	a0,a0,-1960 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201198:	a3aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(count == 0);
ffffffffc020119c:	00002697          	auipc	a3,0x2
ffffffffc02011a0:	b6c68693          	addi	a3,a3,-1172 # ffffffffc0202d08 <messages.0+0x3b8>
ffffffffc02011a4:	00002617          	auipc	a2,0x2
ffffffffc02011a8:	82c60613          	addi	a2,a2,-2004 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02011ac:	11d00593          	li	a1,285
ffffffffc02011b0:	00002517          	auipc	a0,0x2
ffffffffc02011b4:	83850513          	addi	a0,a0,-1992 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02011b8:	a1aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(nr_free == 0);
ffffffffc02011bc:	00002697          	auipc	a3,0x2
ffffffffc02011c0:	9ec68693          	addi	a3,a3,-1556 # ffffffffc0202ba8 <messages.0+0x258>
ffffffffc02011c4:	00002617          	auipc	a2,0x2
ffffffffc02011c8:	80c60613          	addi	a2,a2,-2036 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02011cc:	11200593          	li	a1,274
ffffffffc02011d0:	00002517          	auipc	a0,0x2
ffffffffc02011d4:	81850513          	addi	a0,a0,-2024 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02011d8:	9faff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc02011dc:	00002697          	auipc	a3,0x2
ffffffffc02011e0:	96c68693          	addi	a3,a3,-1684 # ffffffffc0202b48 <messages.0+0x1f8>
ffffffffc02011e4:	00001617          	auipc	a2,0x1
ffffffffc02011e8:	7ec60613          	addi	a2,a2,2028 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02011ec:	11000593          	li	a1,272
ffffffffc02011f0:	00001517          	auipc	a0,0x1
ffffffffc02011f4:	7f850513          	addi	a0,a0,2040 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02011f8:	9daff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(page2pa(p1) < npage * PGSIZE);
ffffffffc02011fc:	00002697          	auipc	a3,0x2
ffffffffc0201200:	90c68693          	addi	a3,a3,-1780 # ffffffffc0202b08 <messages.0+0x1b8>
ffffffffc0201204:	00001617          	auipc	a2,0x1
ffffffffc0201208:	7cc60613          	addi	a2,a2,1996 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020120c:	0b900593          	li	a1,185
ffffffffc0201210:	00001517          	auipc	a0,0x1
ffffffffc0201214:	7d850513          	addi	a0,a0,2008 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201218:	9baff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p0 = alloc_pages(2)) == p2 + 1);
ffffffffc020121c:	00002697          	auipc	a3,0x2
ffffffffc0201220:	aac68693          	addi	a3,a3,-1364 # ffffffffc0202cc8 <messages.0+0x378>
ffffffffc0201224:	00001617          	auipc	a2,0x1
ffffffffc0201228:	7ac60613          	addi	a2,a2,1964 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020122c:	10a00593          	li	a1,266
ffffffffc0201230:	00001517          	auipc	a0,0x1
ffffffffc0201234:	7b850513          	addi	a0,a0,1976 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201238:	99aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p0 = alloc_page()) == p2 - 1);
ffffffffc020123c:	00002697          	auipc	a3,0x2
ffffffffc0201240:	a6c68693          	addi	a3,a3,-1428 # ffffffffc0202ca8 <messages.0+0x358>
ffffffffc0201244:	00001617          	auipc	a2,0x1
ffffffffc0201248:	78c60613          	addi	a2,a2,1932 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020124c:	10800593          	li	a1,264
ffffffffc0201250:	00001517          	auipc	a0,0x1
ffffffffc0201254:	79850513          	addi	a0,a0,1944 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201258:	97aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(PageProperty(p1) && p1->property == 3);
ffffffffc020125c:	00002697          	auipc	a3,0x2
ffffffffc0201260:	a2468693          	addi	a3,a3,-1500 # ffffffffc0202c80 <messages.0+0x330>
ffffffffc0201264:	00001617          	auipc	a2,0x1
ffffffffc0201268:	76c60613          	addi	a2,a2,1900 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020126c:	10600593          	li	a1,262
ffffffffc0201270:	00001517          	auipc	a0,0x1
ffffffffc0201274:	77850513          	addi	a0,a0,1912 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201278:	95aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(PageProperty(p0) && p0->property == 1);
ffffffffc020127c:	00002697          	auipc	a3,0x2
ffffffffc0201280:	9dc68693          	addi	a3,a3,-1572 # ffffffffc0202c58 <messages.0+0x308>
ffffffffc0201284:	00001617          	auipc	a2,0x1
ffffffffc0201288:	74c60613          	addi	a2,a2,1868 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020128c:	10500593          	li	a1,261
ffffffffc0201290:	00001517          	auipc	a0,0x1
ffffffffc0201294:	75850513          	addi	a0,a0,1880 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201298:	93aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(p0 + 2 == p1);
ffffffffc020129c:	00002697          	auipc	a3,0x2
ffffffffc02012a0:	9ac68693          	addi	a3,a3,-1620 # ffffffffc0202c48 <messages.0+0x2f8>
ffffffffc02012a4:	00001617          	auipc	a2,0x1
ffffffffc02012a8:	72c60613          	addi	a2,a2,1836 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02012ac:	10000593          	li	a1,256
ffffffffc02012b0:	00001517          	auipc	a0,0x1
ffffffffc02012b4:	73850513          	addi	a0,a0,1848 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02012b8:	91aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc02012bc:	00002697          	auipc	a3,0x2
ffffffffc02012c0:	88c68693          	addi	a3,a3,-1908 # ffffffffc0202b48 <messages.0+0x1f8>
ffffffffc02012c4:	00001617          	auipc	a2,0x1
ffffffffc02012c8:	70c60613          	addi	a2,a2,1804 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02012cc:	0ff00593          	li	a1,255
ffffffffc02012d0:	00001517          	auipc	a0,0x1
ffffffffc02012d4:	71850513          	addi	a0,a0,1816 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02012d8:	8faff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p1 = alloc_pages(3)) != NULL);
ffffffffc02012dc:	00002697          	auipc	a3,0x2
ffffffffc02012e0:	94c68693          	addi	a3,a3,-1716 # ffffffffc0202c28 <messages.0+0x2d8>
ffffffffc02012e4:	00001617          	auipc	a2,0x1
ffffffffc02012e8:	6ec60613          	addi	a2,a2,1772 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02012ec:	0fe00593          	li	a1,254
ffffffffc02012f0:	00001517          	auipc	a0,0x1
ffffffffc02012f4:	6f850513          	addi	a0,a0,1784 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02012f8:	8daff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(PageProperty(p0 + 2) && p0[2].property == 3);
ffffffffc02012fc:	00002697          	auipc	a3,0x2
ffffffffc0201300:	8fc68693          	addi	a3,a3,-1796 # ffffffffc0202bf8 <messages.0+0x2a8>
ffffffffc0201304:	00001617          	auipc	a2,0x1
ffffffffc0201308:	6cc60613          	addi	a2,a2,1740 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020130c:	0fd00593          	li	a1,253
ffffffffc0201310:	00001517          	auipc	a0,0x1
ffffffffc0201314:	6d850513          	addi	a0,a0,1752 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201318:	8baff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_pages(4) == NULL);
ffffffffc020131c:	00002697          	auipc	a3,0x2
ffffffffc0201320:	8c468693          	addi	a3,a3,-1852 # ffffffffc0202be0 <messages.0+0x290>
ffffffffc0201324:	00001617          	auipc	a2,0x1
ffffffffc0201328:	6ac60613          	addi	a2,a2,1708 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020132c:	0fc00593          	li	a1,252
ffffffffc0201330:	00001517          	auipc	a0,0x1
ffffffffc0201334:	6b850513          	addi	a0,a0,1720 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201338:	89aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(alloc_page() == NULL);
ffffffffc020133c:	00002697          	auipc	a3,0x2
ffffffffc0201340:	80c68693          	addi	a3,a3,-2036 # ffffffffc0202b48 <messages.0+0x1f8>
ffffffffc0201344:	00001617          	auipc	a2,0x1
ffffffffc0201348:	68c60613          	addi	a2,a2,1676 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020134c:	0f600593          	li	a1,246
ffffffffc0201350:	00001517          	auipc	a0,0x1
ffffffffc0201354:	69850513          	addi	a0,a0,1688 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201358:	87aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(!PageProperty(p0));
ffffffffc020135c:	00002697          	auipc	a3,0x2
ffffffffc0201360:	86c68693          	addi	a3,a3,-1940 # ffffffffc0202bc8 <messages.0+0x278>
ffffffffc0201364:	00001617          	auipc	a2,0x1
ffffffffc0201368:	66c60613          	addi	a2,a2,1644 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020136c:	0f100593          	li	a1,241
ffffffffc0201370:	00001517          	auipc	a0,0x1
ffffffffc0201374:	67850513          	addi	a0,a0,1656 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201378:	85aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p0 = alloc_pages(5)) != NULL);
ffffffffc020137c:	00002697          	auipc	a3,0x2
ffffffffc0201380:	96c68693          	addi	a3,a3,-1684 # ffffffffc0202ce8 <messages.0+0x398>
ffffffffc0201384:	00001617          	auipc	a2,0x1
ffffffffc0201388:	64c60613          	addi	a2,a2,1612 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020138c:	10f00593          	li	a1,271
ffffffffc0201390:	00001517          	auipc	a0,0x1
ffffffffc0201394:	65850513          	addi	a0,a0,1624 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201398:	83aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(total == 0);
ffffffffc020139c:	00002697          	auipc	a3,0x2
ffffffffc02013a0:	97c68693          	addi	a3,a3,-1668 # ffffffffc0202d18 <messages.0+0x3c8>
ffffffffc02013a4:	00001617          	auipc	a2,0x1
ffffffffc02013a8:	62c60613          	addi	a2,a2,1580 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02013ac:	11e00593          	li	a1,286
ffffffffc02013b0:	00001517          	auipc	a0,0x1
ffffffffc02013b4:	63850513          	addi	a0,a0,1592 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02013b8:	81aff0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(total == nr_free_pages());
ffffffffc02013bc:	00001697          	auipc	a3,0x1
ffffffffc02013c0:	64468693          	addi	a3,a3,1604 # ffffffffc0202a00 <messages.0+0xb0>
ffffffffc02013c4:	00001617          	auipc	a2,0x1
ffffffffc02013c8:	60c60613          	addi	a2,a2,1548 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02013cc:	0eb00593          	li	a1,235
ffffffffc02013d0:	00001517          	auipc	a0,0x1
ffffffffc02013d4:	61850513          	addi	a0,a0,1560 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02013d8:	ffbfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert((p1 = alloc_page()) != NULL);
ffffffffc02013dc:	00001697          	auipc	a3,0x1
ffffffffc02013e0:	66468693          	addi	a3,a3,1636 # ffffffffc0202a40 <messages.0+0xf0>
ffffffffc02013e4:	00001617          	auipc	a2,0x1
ffffffffc02013e8:	5ec60613          	addi	a2,a2,1516 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02013ec:	0b200593          	li	a1,178
ffffffffc02013f0:	00001517          	auipc	a0,0x1
ffffffffc02013f4:	5f850513          	addi	a0,a0,1528 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02013f8:	fdbfe0ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc02013fc <default_free_pages>:
default_free_pages(struct Page *base, size_t n) {
ffffffffc02013fc:	1141                	addi	sp,sp,-16
ffffffffc02013fe:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0201400:	14058a63          	beqz	a1,ffffffffc0201554 <default_free_pages+0x158>
    for (; p != base + n; p ++) {
ffffffffc0201404:	00259693          	slli	a3,a1,0x2
ffffffffc0201408:	96ae                	add	a3,a3,a1
ffffffffc020140a:	068e                	slli	a3,a3,0x3
ffffffffc020140c:	96aa                	add	a3,a3,a0
ffffffffc020140e:	87aa                	mv	a5,a0
ffffffffc0201410:	02d50263          	beq	a0,a3,ffffffffc0201434 <default_free_pages+0x38>
ffffffffc0201414:	6798                	ld	a4,8(a5)
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0201416:	8b05                	andi	a4,a4,1
ffffffffc0201418:	10071e63          	bnez	a4,ffffffffc0201534 <default_free_pages+0x138>
ffffffffc020141c:	6798                	ld	a4,8(a5)
ffffffffc020141e:	8b09                	andi	a4,a4,2
ffffffffc0201420:	10071a63          	bnez	a4,ffffffffc0201534 <default_free_pages+0x138>
        p->flags = 0;
ffffffffc0201424:	0007b423          	sd	zero,8(a5)



static inline int page_ref(struct Page *page) { return page->ref; }

static inline void set_page_ref(struct Page *page, int val) { page->ref = val; }
ffffffffc0201428:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc020142c:	02878793          	addi	a5,a5,40
ffffffffc0201430:	fed792e3          	bne	a5,a3,ffffffffc0201414 <default_free_pages+0x18>
    base->property = n;
ffffffffc0201434:	2581                	sext.w	a1,a1
ffffffffc0201436:	c90c                	sw	a1,16(a0)
    SetPageProperty(base);
ffffffffc0201438:	00850893          	addi	a7,a0,8
    __op_bit(or, __NOP, nr, ((volatile unsigned long *)addr));
ffffffffc020143c:	4789                	li	a5,2
ffffffffc020143e:	40f8b02f          	amoor.d	zero,a5,(a7)
    nr_free += n;
ffffffffc0201442:	00006697          	auipc	a3,0x6
ffffffffc0201446:	be668693          	addi	a3,a3,-1050 # ffffffffc0207028 <free_area>
ffffffffc020144a:	4a98                	lw	a4,16(a3)
    return list->next == list;
ffffffffc020144c:	669c                	ld	a5,8(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc020144e:	01850613          	addi	a2,a0,24
    nr_free += n;
ffffffffc0201452:	9db9                	addw	a1,a1,a4
ffffffffc0201454:	ca8c                	sw	a1,16(a3)
    if (list_empty(&free_list)) {
ffffffffc0201456:	0ad78863          	beq	a5,a3,ffffffffc0201506 <default_free_pages+0x10a>
            struct Page* page = le2page(le, page_link);
ffffffffc020145a:	fe878713          	addi	a4,a5,-24
ffffffffc020145e:	0006b803          	ld	a6,0(a3)
    if (list_empty(&free_list)) {
ffffffffc0201462:	4581                	li	a1,0
            if (base < page) {
ffffffffc0201464:	00e56a63          	bltu	a0,a4,ffffffffc0201478 <default_free_pages+0x7c>
    return listelm->next;
ffffffffc0201468:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc020146a:	06d70263          	beq	a4,a3,ffffffffc02014ce <default_free_pages+0xd2>
    for (; p != base + n; p ++) {
ffffffffc020146e:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc0201470:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc0201474:	fee57ae3          	bgeu	a0,a4,ffffffffc0201468 <default_free_pages+0x6c>
ffffffffc0201478:	c199                	beqz	a1,ffffffffc020147e <default_free_pages+0x82>
ffffffffc020147a:	0106b023          	sd	a6,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc020147e:	6398                	ld	a4,0(a5)
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_add(list_entry_t *elm, list_entry_t *prev, list_entry_t *next) {
    prev->next = next->prev = elm;
ffffffffc0201480:	e390                	sd	a2,0(a5)
ffffffffc0201482:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc0201484:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc0201486:	ed18                	sd	a4,24(a0)
    if (le != &free_list) {
ffffffffc0201488:	02d70063          	beq	a4,a3,ffffffffc02014a8 <default_free_pages+0xac>
        if (p + p->property == base) {
ffffffffc020148c:	ff872803          	lw	a6,-8(a4)
        p = le2page(le, page_link);
ffffffffc0201490:	fe870593          	addi	a1,a4,-24
        if (p + p->property == base) {
ffffffffc0201494:	02081613          	slli	a2,a6,0x20
ffffffffc0201498:	9201                	srli	a2,a2,0x20
ffffffffc020149a:	00261793          	slli	a5,a2,0x2
ffffffffc020149e:	97b2                	add	a5,a5,a2
ffffffffc02014a0:	078e                	slli	a5,a5,0x3
ffffffffc02014a2:	97ae                	add	a5,a5,a1
ffffffffc02014a4:	02f50f63          	beq	a0,a5,ffffffffc02014e2 <default_free_pages+0xe6>
    return listelm->next;
ffffffffc02014a8:	7118                	ld	a4,32(a0)
    if (le != &free_list) {
ffffffffc02014aa:	00d70f63          	beq	a4,a3,ffffffffc02014c8 <default_free_pages+0xcc>
        if (base + base->property == p) {
ffffffffc02014ae:	490c                	lw	a1,16(a0)
        p = le2page(le, page_link);
ffffffffc02014b0:	fe870693          	addi	a3,a4,-24
        if (base + base->property == p) {
ffffffffc02014b4:	02059613          	slli	a2,a1,0x20
ffffffffc02014b8:	9201                	srli	a2,a2,0x20
ffffffffc02014ba:	00261793          	slli	a5,a2,0x2
ffffffffc02014be:	97b2                	add	a5,a5,a2
ffffffffc02014c0:	078e                	slli	a5,a5,0x3
ffffffffc02014c2:	97aa                	add	a5,a5,a0
ffffffffc02014c4:	04f68863          	beq	a3,a5,ffffffffc0201514 <default_free_pages+0x118>
}
ffffffffc02014c8:	60a2                	ld	ra,8(sp)
ffffffffc02014ca:	0141                	addi	sp,sp,16
ffffffffc02014cc:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc02014ce:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc02014d0:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc02014d2:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc02014d4:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc02014d6:	02d70563          	beq	a4,a3,ffffffffc0201500 <default_free_pages+0x104>
    prev->next = next->prev = elm;
ffffffffc02014da:	8832                	mv	a6,a2
ffffffffc02014dc:	4585                	li	a1,1
    for (; p != base + n; p ++) {
ffffffffc02014de:	87ba                	mv	a5,a4
ffffffffc02014e0:	bf41                	j	ffffffffc0201470 <default_free_pages+0x74>
            p->property += base->property;
ffffffffc02014e2:	491c                	lw	a5,16(a0)
ffffffffc02014e4:	0107883b          	addw	a6,a5,a6
ffffffffc02014e8:	ff072c23          	sw	a6,-8(a4)
    __op_bit(and, __NOT, nr, ((volatile unsigned long *)addr));
ffffffffc02014ec:	57f5                	li	a5,-3
ffffffffc02014ee:	60f8b02f          	amoand.d	zero,a5,(a7)
    __list_del(listelm->prev, listelm->next);
ffffffffc02014f2:	6d10                	ld	a2,24(a0)
ffffffffc02014f4:	711c                	ld	a5,32(a0)
            base = p;
ffffffffc02014f6:	852e                	mv	a0,a1
 * This is only for internal list manipulation where we know
 * the prev/next entries already!
 * */
static inline void
__list_del(list_entry_t *prev, list_entry_t *next) {
    prev->next = next;
ffffffffc02014f8:	e61c                	sd	a5,8(a2)
    return listelm->next;
ffffffffc02014fa:	6718                	ld	a4,8(a4)
    next->prev = prev;
ffffffffc02014fc:	e390                	sd	a2,0(a5)
ffffffffc02014fe:	b775                	j	ffffffffc02014aa <default_free_pages+0xae>
ffffffffc0201500:	e290                	sd	a2,0(a3)
        while ((le = list_next(le)) != &free_list) {
ffffffffc0201502:	873e                	mv	a4,a5
ffffffffc0201504:	b761                	j	ffffffffc020148c <default_free_pages+0x90>
}
ffffffffc0201506:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc0201508:	e390                	sd	a2,0(a5)
ffffffffc020150a:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc020150c:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc020150e:	ed1c                	sd	a5,24(a0)
ffffffffc0201510:	0141                	addi	sp,sp,16
ffffffffc0201512:	8082                	ret
            base->property += p->property;
ffffffffc0201514:	ff872783          	lw	a5,-8(a4)
ffffffffc0201518:	ff070693          	addi	a3,a4,-16
ffffffffc020151c:	9dbd                	addw	a1,a1,a5
ffffffffc020151e:	c90c                	sw	a1,16(a0)
ffffffffc0201520:	57f5                	li	a5,-3
ffffffffc0201522:	60f6b02f          	amoand.d	zero,a5,(a3)
    __list_del(listelm->prev, listelm->next);
ffffffffc0201526:	6314                	ld	a3,0(a4)
ffffffffc0201528:	671c                	ld	a5,8(a4)
}
ffffffffc020152a:	60a2                	ld	ra,8(sp)
    prev->next = next;
ffffffffc020152c:	e69c                	sd	a5,8(a3)
    next->prev = prev;
ffffffffc020152e:	e394                	sd	a3,0(a5)
ffffffffc0201530:	0141                	addi	sp,sp,16
ffffffffc0201532:	8082                	ret
        assert(!PageReserved(p) && !PageProperty(p));
ffffffffc0201534:	00001697          	auipc	a3,0x1
ffffffffc0201538:	7fc68693          	addi	a3,a3,2044 # ffffffffc0202d30 <messages.0+0x3e0>
ffffffffc020153c:	00001617          	auipc	a2,0x1
ffffffffc0201540:	49460613          	addi	a2,a2,1172 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc0201544:	07b00593          	li	a1,123
ffffffffc0201548:	00001517          	auipc	a0,0x1
ffffffffc020154c:	4a050513          	addi	a0,a0,1184 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201550:	e83fe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(n > 0);
ffffffffc0201554:	00001697          	auipc	a3,0x1
ffffffffc0201558:	7d468693          	addi	a3,a3,2004 # ffffffffc0202d28 <messages.0+0x3d8>
ffffffffc020155c:	00001617          	auipc	a2,0x1
ffffffffc0201560:	47460613          	addi	a2,a2,1140 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc0201564:	07800593          	li	a1,120
ffffffffc0201568:	00001517          	auipc	a0,0x1
ffffffffc020156c:	48050513          	addi	a0,a0,1152 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc0201570:	e63fe0ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc0201574 <default_alloc_pages>:
    assert(n > 0);
ffffffffc0201574:	c959                	beqz	a0,ffffffffc020160a <default_alloc_pages+0x96>
    if (n > nr_free) {
ffffffffc0201576:	00006597          	auipc	a1,0x6
ffffffffc020157a:	ab258593          	addi	a1,a1,-1358 # ffffffffc0207028 <free_area>
ffffffffc020157e:	0105a803          	lw	a6,16(a1)
ffffffffc0201582:	862a                	mv	a2,a0
ffffffffc0201584:	02081793          	slli	a5,a6,0x20
ffffffffc0201588:	9381                	srli	a5,a5,0x20
ffffffffc020158a:	00a7ee63          	bltu	a5,a0,ffffffffc02015a6 <default_alloc_pages+0x32>
    list_entry_t *le = &free_list;
ffffffffc020158e:	87ae                	mv	a5,a1
ffffffffc0201590:	a801                	j	ffffffffc02015a0 <default_alloc_pages+0x2c>
        if (p->property >= n) {
ffffffffc0201592:	ff87a703          	lw	a4,-8(a5)
ffffffffc0201596:	02071693          	slli	a3,a4,0x20
ffffffffc020159a:	9281                	srli	a3,a3,0x20
ffffffffc020159c:	00c6f763          	bgeu	a3,a2,ffffffffc02015aa <default_alloc_pages+0x36>
    return listelm->next;
ffffffffc02015a0:	679c                	ld	a5,8(a5)
    while ((le = list_next(le)) != &free_list) {
ffffffffc02015a2:	feb798e3          	bne	a5,a1,ffffffffc0201592 <default_alloc_pages+0x1e>
        return NULL;
ffffffffc02015a6:	4501                	li	a0,0
}
ffffffffc02015a8:	8082                	ret
    return listelm->prev;
ffffffffc02015aa:	0007b883          	ld	a7,0(a5)
    __list_del(listelm->prev, listelm->next);
ffffffffc02015ae:	0087b303          	ld	t1,8(a5)
        struct Page *p = le2page(le, page_link);
ffffffffc02015b2:	fe878513          	addi	a0,a5,-24
            p->property = page->property - n;
ffffffffc02015b6:	00060e1b          	sext.w	t3,a2
    prev->next = next;
ffffffffc02015ba:	0068b423          	sd	t1,8(a7)
    next->prev = prev;
ffffffffc02015be:	01133023          	sd	a7,0(t1)
        if (page->property > n) {
ffffffffc02015c2:	02d67b63          	bgeu	a2,a3,ffffffffc02015f8 <default_alloc_pages+0x84>
            struct Page *p = page + n;
ffffffffc02015c6:	00261693          	slli	a3,a2,0x2
ffffffffc02015ca:	96b2                	add	a3,a3,a2
ffffffffc02015cc:	068e                	slli	a3,a3,0x3
ffffffffc02015ce:	96aa                	add	a3,a3,a0
            p->property = page->property - n;
ffffffffc02015d0:	41c7073b          	subw	a4,a4,t3
ffffffffc02015d4:	ca98                	sw	a4,16(a3)
    __op_bit(or, __NOP, nr, ((volatile unsigned long *)addr));
ffffffffc02015d6:	00868613          	addi	a2,a3,8
ffffffffc02015da:	4709                	li	a4,2
ffffffffc02015dc:	40e6302f          	amoor.d	zero,a4,(a2)
    __list_add(elm, listelm, listelm->next);
ffffffffc02015e0:	0088b703          	ld	a4,8(a7)
            list_add(prev, &(p->page_link));
ffffffffc02015e4:	01868613          	addi	a2,a3,24
        nr_free -= n;
ffffffffc02015e8:	0105a803          	lw	a6,16(a1)
    prev->next = next->prev = elm;
ffffffffc02015ec:	e310                	sd	a2,0(a4)
ffffffffc02015ee:	00c8b423          	sd	a2,8(a7)
    elm->next = next;
ffffffffc02015f2:	f298                	sd	a4,32(a3)
    elm->prev = prev;
ffffffffc02015f4:	0116bc23          	sd	a7,24(a3)
ffffffffc02015f8:	41c8083b          	subw	a6,a6,t3
ffffffffc02015fc:	0105a823          	sw	a6,16(a1)
    __op_bit(and, __NOT, nr, ((volatile unsigned long *)addr));
ffffffffc0201600:	5775                	li	a4,-3
ffffffffc0201602:	17c1                	addi	a5,a5,-16
ffffffffc0201604:	60e7b02f          	amoand.d	zero,a4,(a5)
}
ffffffffc0201608:	8082                	ret
default_alloc_pages(size_t n) {
ffffffffc020160a:	1141                	addi	sp,sp,-16
    assert(n > 0);
ffffffffc020160c:	00001697          	auipc	a3,0x1
ffffffffc0201610:	71c68693          	addi	a3,a3,1820 # ffffffffc0202d28 <messages.0+0x3d8>
ffffffffc0201614:	00001617          	auipc	a2,0x1
ffffffffc0201618:	3bc60613          	addi	a2,a2,956 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc020161c:	05a00593          	li	a1,90
ffffffffc0201620:	00001517          	auipc	a0,0x1
ffffffffc0201624:	3c850513          	addi	a0,a0,968 # ffffffffc02029e8 <messages.0+0x98>
default_alloc_pages(size_t n) {
ffffffffc0201628:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc020162a:	da9fe0ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc020162e <default_init_memmap>:
default_init_memmap(struct Page *base, size_t n) {
ffffffffc020162e:	1141                	addi	sp,sp,-16
ffffffffc0201630:	e406                	sd	ra,8(sp)
    assert(n > 0);
ffffffffc0201632:	c9e1                	beqz	a1,ffffffffc0201702 <default_init_memmap+0xd4>
    for (; p != base + n; p ++) {
ffffffffc0201634:	00259693          	slli	a3,a1,0x2
ffffffffc0201638:	96ae                	add	a3,a3,a1
ffffffffc020163a:	068e                	slli	a3,a3,0x3
ffffffffc020163c:	96aa                	add	a3,a3,a0
ffffffffc020163e:	87aa                	mv	a5,a0
ffffffffc0201640:	00d50f63          	beq	a0,a3,ffffffffc020165e <default_init_memmap+0x30>
    return (((*(volatile unsigned long *)addr) >> nr) & 1);
ffffffffc0201644:	6798                	ld	a4,8(a5)
        assert(PageReserved(p));
ffffffffc0201646:	8b05                	andi	a4,a4,1
ffffffffc0201648:	cf49                	beqz	a4,ffffffffc02016e2 <default_init_memmap+0xb4>
        p->flags = p->property = 0;
ffffffffc020164a:	0007a823          	sw	zero,16(a5)
ffffffffc020164e:	0007b423          	sd	zero,8(a5)
ffffffffc0201652:	0007a023          	sw	zero,0(a5)
    for (; p != base + n; p ++) {
ffffffffc0201656:	02878793          	addi	a5,a5,40
ffffffffc020165a:	fed795e3          	bne	a5,a3,ffffffffc0201644 <default_init_memmap+0x16>
    base->property = n;
ffffffffc020165e:	2581                	sext.w	a1,a1
ffffffffc0201660:	c90c                	sw	a1,16(a0)
    __op_bit(or, __NOP, nr, ((volatile unsigned long *)addr));
ffffffffc0201662:	4789                	li	a5,2
ffffffffc0201664:	00850713          	addi	a4,a0,8
ffffffffc0201668:	40f7302f          	amoor.d	zero,a5,(a4)
    nr_free += n;
ffffffffc020166c:	00006697          	auipc	a3,0x6
ffffffffc0201670:	9bc68693          	addi	a3,a3,-1604 # ffffffffc0207028 <free_area>
ffffffffc0201674:	4a98                	lw	a4,16(a3)
    return list->next == list;
ffffffffc0201676:	669c                	ld	a5,8(a3)
        list_add(&free_list, &(base->page_link));
ffffffffc0201678:	01850613          	addi	a2,a0,24
    nr_free += n;
ffffffffc020167c:	9db9                	addw	a1,a1,a4
ffffffffc020167e:	ca8c                	sw	a1,16(a3)
    if (list_empty(&free_list)) {
ffffffffc0201680:	04d78a63          	beq	a5,a3,ffffffffc02016d4 <default_init_memmap+0xa6>
            struct Page* page = le2page(le, page_link);
ffffffffc0201684:	fe878713          	addi	a4,a5,-24
ffffffffc0201688:	0006b803          	ld	a6,0(a3)
    if (list_empty(&free_list)) {
ffffffffc020168c:	4581                	li	a1,0
            if (base < page) {
ffffffffc020168e:	00e56a63          	bltu	a0,a4,ffffffffc02016a2 <default_init_memmap+0x74>
    return listelm->next;
ffffffffc0201692:	6798                	ld	a4,8(a5)
            } else if (list_next(le) == &free_list) {
ffffffffc0201694:	02d70263          	beq	a4,a3,ffffffffc02016b8 <default_init_memmap+0x8a>
    for (; p != base + n; p ++) {
ffffffffc0201698:	87ba                	mv	a5,a4
            struct Page* page = le2page(le, page_link);
ffffffffc020169a:	fe878713          	addi	a4,a5,-24
            if (base < page) {
ffffffffc020169e:	fee57ae3          	bgeu	a0,a4,ffffffffc0201692 <default_init_memmap+0x64>
ffffffffc02016a2:	c199                	beqz	a1,ffffffffc02016a8 <default_init_memmap+0x7a>
ffffffffc02016a4:	0106b023          	sd	a6,0(a3)
    __list_add(elm, listelm->prev, listelm);
ffffffffc02016a8:	6398                	ld	a4,0(a5)
}
ffffffffc02016aa:	60a2                	ld	ra,8(sp)
    prev->next = next->prev = elm;
ffffffffc02016ac:	e390                	sd	a2,0(a5)
ffffffffc02016ae:	e710                	sd	a2,8(a4)
    elm->next = next;
ffffffffc02016b0:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc02016b2:	ed18                	sd	a4,24(a0)
ffffffffc02016b4:	0141                	addi	sp,sp,16
ffffffffc02016b6:	8082                	ret
    prev->next = next->prev = elm;
ffffffffc02016b8:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc02016ba:	f114                	sd	a3,32(a0)
    return listelm->next;
ffffffffc02016bc:	6798                	ld	a4,8(a5)
    elm->prev = prev;
ffffffffc02016be:	ed1c                	sd	a5,24(a0)
        while ((le = list_next(le)) != &free_list) {
ffffffffc02016c0:	00d70663          	beq	a4,a3,ffffffffc02016cc <default_init_memmap+0x9e>
    prev->next = next->prev = elm;
ffffffffc02016c4:	8832                	mv	a6,a2
ffffffffc02016c6:	4585                	li	a1,1
    for (; p != base + n; p ++) {
ffffffffc02016c8:	87ba                	mv	a5,a4
ffffffffc02016ca:	bfc1                	j	ffffffffc020169a <default_init_memmap+0x6c>
}
ffffffffc02016cc:	60a2                	ld	ra,8(sp)
ffffffffc02016ce:	e290                	sd	a2,0(a3)
ffffffffc02016d0:	0141                	addi	sp,sp,16
ffffffffc02016d2:	8082                	ret
ffffffffc02016d4:	60a2                	ld	ra,8(sp)
ffffffffc02016d6:	e390                	sd	a2,0(a5)
ffffffffc02016d8:	e790                	sd	a2,8(a5)
    elm->next = next;
ffffffffc02016da:	f11c                	sd	a5,32(a0)
    elm->prev = prev;
ffffffffc02016dc:	ed1c                	sd	a5,24(a0)
ffffffffc02016de:	0141                	addi	sp,sp,16
ffffffffc02016e0:	8082                	ret
        assert(PageReserved(p));
ffffffffc02016e2:	00001697          	auipc	a3,0x1
ffffffffc02016e6:	67668693          	addi	a3,a3,1654 # ffffffffc0202d58 <messages.0+0x408>
ffffffffc02016ea:	00001617          	auipc	a2,0x1
ffffffffc02016ee:	2e660613          	addi	a2,a2,742 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc02016f2:	04100593          	li	a1,65
ffffffffc02016f6:	00001517          	auipc	a0,0x1
ffffffffc02016fa:	2f250513          	addi	a0,a0,754 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc02016fe:	cd5fe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    assert(n > 0);
ffffffffc0201702:	00001697          	auipc	a3,0x1
ffffffffc0201706:	62668693          	addi	a3,a3,1574 # ffffffffc0202d28 <messages.0+0x3d8>
ffffffffc020170a:	00001617          	auipc	a2,0x1
ffffffffc020170e:	2c660613          	addi	a2,a2,710 # ffffffffc02029d0 <messages.0+0x80>
ffffffffc0201712:	03e00593          	li	a1,62
ffffffffc0201716:	00001517          	auipc	a0,0x1
ffffffffc020171a:	2d250513          	addi	a0,a0,722 # ffffffffc02029e8 <messages.0+0x98>
ffffffffc020171e:	cb5fe0ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc0201722 <alloc_pages>:
#include <defs.h>
#include <intr.h>
#include <riscv.h>

static inline bool __intr_save(void) {
    if (read_csr(sstatus) & SSTATUS_SIE) {
ffffffffc0201722:	100027f3          	csrr	a5,sstatus
ffffffffc0201726:	8b89                	andi	a5,a5,2
ffffffffc0201728:	e799                	bnez	a5,ffffffffc0201736 <alloc_pages+0x14>
struct Page *alloc_pages(size_t n) {
    struct Page *page = NULL;
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        page = pmm_manager->alloc_pages(n);
ffffffffc020172a:	00006797          	auipc	a5,0x6
ffffffffc020172e:	d467b783          	ld	a5,-698(a5) # ffffffffc0207470 <pmm_manager>
ffffffffc0201732:	6f9c                	ld	a5,24(a5)
ffffffffc0201734:	8782                	jr	a5
struct Page *alloc_pages(size_t n) {
ffffffffc0201736:	1141                	addi	sp,sp,-16
ffffffffc0201738:	e406                	sd	ra,8(sp)
ffffffffc020173a:	e022                	sd	s0,0(sp)
ffffffffc020173c:	842a                	mv	s0,a0
        intr_disable();
ffffffffc020173e:	8f6ff0ef          	jal	ra,ffffffffc0200834 <intr_disable>
        page = pmm_manager->alloc_pages(n);
ffffffffc0201742:	00006797          	auipc	a5,0x6
ffffffffc0201746:	d2e7b783          	ld	a5,-722(a5) # ffffffffc0207470 <pmm_manager>
ffffffffc020174a:	6f9c                	ld	a5,24(a5)
ffffffffc020174c:	8522                	mv	a0,s0
ffffffffc020174e:	9782                	jalr	a5
ffffffffc0201750:	842a                	mv	s0,a0
    return 0;
}

static inline void __intr_restore(bool flag) {
    if (flag) {
        intr_enable();
ffffffffc0201752:	8dcff0ef          	jal	ra,ffffffffc020082e <intr_enable>
    }
    local_intr_restore(intr_flag);
    return page;
}
ffffffffc0201756:	60a2                	ld	ra,8(sp)
ffffffffc0201758:	8522                	mv	a0,s0
ffffffffc020175a:	6402                	ld	s0,0(sp)
ffffffffc020175c:	0141                	addi	sp,sp,16
ffffffffc020175e:	8082                	ret

ffffffffc0201760 <free_pages>:
    if (read_csr(sstatus) & SSTATUS_SIE) {
ffffffffc0201760:	100027f3          	csrr	a5,sstatus
ffffffffc0201764:	8b89                	andi	a5,a5,2
ffffffffc0201766:	e799                	bnez	a5,ffffffffc0201774 <free_pages+0x14>
// free_pages - call pmm->free_pages to free a continuous n*PAGESIZE memory
void free_pages(struct Page *base, size_t n) {
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        pmm_manager->free_pages(base, n);
ffffffffc0201768:	00006797          	auipc	a5,0x6
ffffffffc020176c:	d087b783          	ld	a5,-760(a5) # ffffffffc0207470 <pmm_manager>
ffffffffc0201770:	739c                	ld	a5,32(a5)
ffffffffc0201772:	8782                	jr	a5
void free_pages(struct Page *base, size_t n) {
ffffffffc0201774:	1101                	addi	sp,sp,-32
ffffffffc0201776:	ec06                	sd	ra,24(sp)
ffffffffc0201778:	e822                	sd	s0,16(sp)
ffffffffc020177a:	e426                	sd	s1,8(sp)
ffffffffc020177c:	842a                	mv	s0,a0
ffffffffc020177e:	84ae                	mv	s1,a1
        intr_disable();
ffffffffc0201780:	8b4ff0ef          	jal	ra,ffffffffc0200834 <intr_disable>
        pmm_manager->free_pages(base, n);
ffffffffc0201784:	00006797          	auipc	a5,0x6
ffffffffc0201788:	cec7b783          	ld	a5,-788(a5) # ffffffffc0207470 <pmm_manager>
ffffffffc020178c:	739c                	ld	a5,32(a5)
ffffffffc020178e:	85a6                	mv	a1,s1
ffffffffc0201790:	8522                	mv	a0,s0
ffffffffc0201792:	9782                	jalr	a5
    }
    local_intr_restore(intr_flag);
}
ffffffffc0201794:	6442                	ld	s0,16(sp)
ffffffffc0201796:	60e2                	ld	ra,24(sp)
ffffffffc0201798:	64a2                	ld	s1,8(sp)
ffffffffc020179a:	6105                	addi	sp,sp,32
        intr_enable();
ffffffffc020179c:	892ff06f          	j	ffffffffc020082e <intr_enable>

ffffffffc02017a0 <nr_free_pages>:
    if (read_csr(sstatus) & SSTATUS_SIE) {
ffffffffc02017a0:	100027f3          	csrr	a5,sstatus
ffffffffc02017a4:	8b89                	andi	a5,a5,2
ffffffffc02017a6:	e799                	bnez	a5,ffffffffc02017b4 <nr_free_pages+0x14>
size_t nr_free_pages(void) {
    size_t ret;
    bool intr_flag;
    local_intr_save(intr_flag);
    {
        ret = pmm_manager->nr_free_pages();
ffffffffc02017a8:	00006797          	auipc	a5,0x6
ffffffffc02017ac:	cc87b783          	ld	a5,-824(a5) # ffffffffc0207470 <pmm_manager>
ffffffffc02017b0:	779c                	ld	a5,40(a5)
ffffffffc02017b2:	8782                	jr	a5
size_t nr_free_pages(void) {
ffffffffc02017b4:	1141                	addi	sp,sp,-16
ffffffffc02017b6:	e406                	sd	ra,8(sp)
ffffffffc02017b8:	e022                	sd	s0,0(sp)
        intr_disable();
ffffffffc02017ba:	87aff0ef          	jal	ra,ffffffffc0200834 <intr_disable>
        ret = pmm_manager->nr_free_pages();
ffffffffc02017be:	00006797          	auipc	a5,0x6
ffffffffc02017c2:	cb27b783          	ld	a5,-846(a5) # ffffffffc0207470 <pmm_manager>
ffffffffc02017c6:	779c                	ld	a5,40(a5)
ffffffffc02017c8:	9782                	jalr	a5
ffffffffc02017ca:	842a                	mv	s0,a0
        intr_enable();
ffffffffc02017cc:	862ff0ef          	jal	ra,ffffffffc020082e <intr_enable>
    }
    local_intr_restore(intr_flag);
    return ret;
}
ffffffffc02017d0:	60a2                	ld	ra,8(sp)
ffffffffc02017d2:	8522                	mv	a0,s0
ffffffffc02017d4:	6402                	ld	s0,0(sp)
ffffffffc02017d6:	0141                	addi	sp,sp,16
ffffffffc02017d8:	8082                	ret

ffffffffc02017da <pmm_init>:
    pmm_manager = &default_pmm_manager;
ffffffffc02017da:	00001797          	auipc	a5,0x1
ffffffffc02017de:	5a678793          	addi	a5,a5,1446 # ffffffffc0202d80 <default_pmm_manager>
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02017e2:	638c                	ld	a1,0(a5)
        init_memmap(pa2page(free_start), (managed_end - free_start) / PGSIZE);
    }
}

/* pmm_init - initialize the physical memory management */
void pmm_init(void) {
ffffffffc02017e4:	1101                	addi	sp,sp,-32
ffffffffc02017e6:	e822                	sd	s0,16(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc02017e8:	00001517          	auipc	a0,0x1
ffffffffc02017ec:	5d050513          	addi	a0,a0,1488 # ffffffffc0202db8 <default_pmm_manager+0x38>
    pmm_manager = &default_pmm_manager;
ffffffffc02017f0:	00006417          	auipc	s0,0x6
ffffffffc02017f4:	c8040413          	addi	s0,s0,-896 # ffffffffc0207470 <pmm_manager>
void pmm_init(void) {
ffffffffc02017f8:	ec06                	sd	ra,24(sp)
ffffffffc02017fa:	e04a                	sd	s2,0(sp)
    pmm_manager = &default_pmm_manager;
ffffffffc02017fc:	e01c                	sd	a5,0(s0)
void pmm_init(void) {
ffffffffc02017fe:	e426                	sd	s1,8(sp)
    cprintf("memory management: %s\n", pmm_manager->name);
ffffffffc0201800:	8d9fe0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    pmm_manager->init();
ffffffffc0201804:	601c                	ld	a5,0(s0)
ffffffffc0201806:	679c                	ld	a5,8(a5)
ffffffffc0201808:	9782                	jalr	a5
    uint64_t mem_base = get_memory_base();
ffffffffc020180a:	810ff0ef          	jal	ra,ffffffffc020081a <get_memory_base>
ffffffffc020180e:	892a                	mv	s2,a0
    uint64_t mem_size = get_memory_size();
ffffffffc0201810:	814ff0ef          	jal	ra,ffffffffc0200824 <get_memory_size>
    if (mem_base != DRAM_BASE || mem_size == 0 ||
ffffffffc0201814:	4785                	li	a5,1
ffffffffc0201816:	07fe                	slli	a5,a5,0x1f
ffffffffc0201818:	18f91863          	bne	s2,a5,ffffffffc02019a8 <pmm_init+0x1ce>
ffffffffc020181c:	800007b7          	lui	a5,0x80000
ffffffffc0201820:	fff50713          	addi	a4,a0,-1
ffffffffc0201824:	17f9                	addi	a5,a5,-2
ffffffffc0201826:	862a                	mv	a2,a0
ffffffffc0201828:	18e7e063          	bltu	a5,a4,ffffffffc02019a8 <pmm_init+0x1ce>
    uint64_t mem_end = mem_base + mem_size;  // exclusive end
ffffffffc020182c:	012504b3          	add	s1,a0,s2
    cprintf("physical memory: base 0x%016lx, size 0x%016lx, "
ffffffffc0201830:	8726                	mv	a4,s1
ffffffffc0201832:	86ca                	mv	a3,s2
ffffffffc0201834:	85ca                	mv	a1,s2
ffffffffc0201836:	00001517          	auipc	a0,0x1
ffffffffc020183a:	5da50513          	addi	a0,a0,1498 # ffffffffc0202e10 <default_pmm_manager+0x90>
ffffffffc020183e:	89bfe0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    uint64_t managed_end = mem_end < mapped_end_pa ? mem_end : mapped_end_pa;
ffffffffc0201842:	47c5                	li	a5,17
ffffffffc0201844:	07ee                	slli	a5,a5,0x1b
ffffffffc0201846:	8726                	mv	a4,s1
ffffffffc0201848:	1097ea63          	bltu	a5,s1,ffffffffc020195c <pmm_init+0x182>
    managed_end = ROUNDDOWN(managed_end, PGSIZE);
ffffffffc020184c:	767d                	lui	a2,0xfffff
    if (managed_end <= mem_base) {
ffffffffc020184e:	4785                	li	a5,1
    managed_end = ROUNDDOWN(managed_end, PGSIZE);
ffffffffc0201850:	00c775b3          	and	a1,a4,a2
    if (managed_end <= mem_base) {
ffffffffc0201854:	07fe                	slli	a5,a5,0x1f
ffffffffc0201856:	1af58a63          	beq	a1,a5,ffffffffc0201a0a <pmm_init+0x230>
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc020185a:	57f5                	li	a5,-3
ffffffffc020185c:	00007697          	auipc	a3,0x7
ffffffffc0201860:	c3b68693          	addi	a3,a3,-965 # ffffffffc0208497 <end+0xfff>
    npage = PPN(managed_end);
ffffffffc0201864:	00c5de13          	srli	t3,a1,0xc
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201868:	00006497          	auipc	s1,0x6
ffffffffc020186c:	c2048493          	addi	s1,s1,-992 # ffffffffc0207488 <va_pa_offset>
ffffffffc0201870:	07fa                	slli	a5,a5,0x1e
    npage = PPN(managed_end);
ffffffffc0201872:	00006317          	auipc	t1,0x6
ffffffffc0201876:	bee30313          	addi	t1,t1,-1042 # ffffffffc0207460 <npage>
ffffffffc020187a:	8ef1                	and	a3,a3,a2
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc020187c:	00006517          	auipc	a0,0x6
ffffffffc0201880:	bec50513          	addi	a0,a0,-1044 # ffffffffc0207468 <pages>
    size_t page_count = npage - nbase;
ffffffffc0201884:	fff80737          	lui	a4,0xfff80
    va_pa_offset = PHYSICAL_MEMORY_OFFSET;
ffffffffc0201888:	e09c                	sd	a5,0(s1)
    npage = PPN(managed_end);
ffffffffc020188a:	01c33023          	sd	t3,0(t1)
    pages = (struct Page *)ROUNDUP((uintptr_t)end, PGSIZE);
ffffffffc020188e:	e114                	sd	a3,0(a0)
    uintptr_t pages_pa = PADDR(pages);
ffffffffc0201890:	c0200837          	lui	a6,0xc0200
    size_t page_count = npage - nbase;
ffffffffc0201894:	9772                	add	a4,a4,t3
    uintptr_t pages_pa = PADDR(pages);
ffffffffc0201896:	1506ee63          	bltu	a3,a6,ffffffffc02019f2 <pmm_init+0x218>
ffffffffc020189a:	488d                	li	a7,3
ffffffffc020189c:	08fa                	slli	a7,a7,0x1e
ffffffffc020189e:	98b6                	add	a7,a7,a3
    if (pages_pa < KERNBASE - PHYSICAL_MEMORY_OFFSET ||
ffffffffc02018a0:	1315e063          	bltu	a1,a7,ffffffffc02019c0 <pmm_init+0x1e6>
        page_count > (managed_end - pages_pa) / sizeof(struct Page)) {
ffffffffc02018a4:	8f95                	sub	a5,a5,a3
ffffffffc02018a6:	97ae                	add	a5,a5,a1
ffffffffc02018a8:	02800813          	li	a6,40
ffffffffc02018ac:	0307d7b3          	divu	a5,a5,a6
        pages_pa > managed_end ||
ffffffffc02018b0:	10e7e863          	bltu	a5,a4,ffffffffc02019c0 <pmm_init+0x1e6>
    uintptr_t free_start = ROUNDUP(pages_pa + page_count * sizeof(struct Page),
ffffffffc02018b4:	00271813          	slli	a6,a4,0x2
ffffffffc02018b8:	983a                	add	a6,a6,a4
ffffffffc02018ba:	00002797          	auipc	a5,0x2
ffffffffc02018be:	9167b783          	ld	a5,-1770(a5) # ffffffffc02031d0 <error_string+0x40>
ffffffffc02018c2:	080e                	slli	a6,a6,0x3
ffffffffc02018c4:	97b6                	add	a5,a5,a3
ffffffffc02018c6:	983e                	add	a6,a6,a5
ffffffffc02018c8:	00c87833          	and	a6,a6,a2
    for (size_t i = 0; i < page_count; i++) {
ffffffffc02018cc:	c361                	beqz	a4,ffffffffc020198c <pmm_init+0x1b2>
ffffffffc02018ce:	002e1613          	slli	a2,t3,0x2
ffffffffc02018d2:	9672                	add	a2,a2,t3
ffffffffc02018d4:	fec007b7          	lui	a5,0xfec00
ffffffffc02018d8:	060e                	slli	a2,a2,0x3
ffffffffc02018da:	963e                	add	a2,a2,a5
ffffffffc02018dc:	4885                	li	a7,1
ffffffffc02018de:	4781                	li	a5,0
ffffffffc02018e0:	a011                	j	ffffffffc02018e4 <pmm_init+0x10a>
        struct Page *page = &pages[i];
ffffffffc02018e2:	6114                	ld	a3,0(a0)
ffffffffc02018e4:	96be                	add	a3,a3,a5
        page->flags = 0;
ffffffffc02018e6:	0006b423          	sd	zero,8(a3)
ffffffffc02018ea:	00868713          	addi	a4,a3,8
ffffffffc02018ee:	4117302f          	amoor.d	zero,a7,(a4)
        list_init(&page->page_link);
ffffffffc02018f2:	01868713          	addi	a4,a3,24
ffffffffc02018f6:	0006a023          	sw	zero,0(a3)
        page->property = 0;
ffffffffc02018fa:	0006a823          	sw	zero,16(a3)
    elm->prev = elm->next = elm;
ffffffffc02018fe:	f298                	sd	a4,32(a3)
ffffffffc0201900:	ee98                	sd	a4,24(a3)
    for (size_t i = 0; i < page_count; i++) {
ffffffffc0201902:	02878793          	addi	a5,a5,40 # fffffffffec00028 <end+0x3e9f8b90>
ffffffffc0201906:	fcf61ee3          	bne	a2,a5,ffffffffc02018e2 <pmm_init+0x108>
    if (free_start < managed_end) {
ffffffffc020190a:	04b86b63          	bltu	a6,a1,ffffffffc0201960 <pmm_init+0x186>
    satp_physical = PADDR(satp_virtual);
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
}

static void check_alloc_page(void) {
    pmm_manager->check();
ffffffffc020190e:	601c                	ld	a5,0(s0)
ffffffffc0201910:	7b9c                	ld	a5,48(a5)
ffffffffc0201912:	9782                	jalr	a5
    cprintf("check_alloc_page() succeeded!\n");
ffffffffc0201914:	00001517          	auipc	a0,0x1
ffffffffc0201918:	60c50513          	addi	a0,a0,1548 # ffffffffc0202f20 <default_pmm_manager+0x1a0>
ffffffffc020191c:	fbcfe0ef          	jal	ra,ffffffffc02000d8 <cprintf>
    satp_virtual = (pte_t*)boot_page_table_sv39;
ffffffffc0201920:	00004597          	auipc	a1,0x4
ffffffffc0201924:	6e058593          	addi	a1,a1,1760 # ffffffffc0206000 <boot_page_table_sv39>
ffffffffc0201928:	00006797          	auipc	a5,0x6
ffffffffc020192c:	b4b7bc23          	sd	a1,-1192(a5) # ffffffffc0207480 <satp_virtual>
    satp_physical = PADDR(satp_virtual);
ffffffffc0201930:	c02007b7          	lui	a5,0xc0200
ffffffffc0201934:	0af5e263          	bltu	a1,a5,ffffffffc02019d8 <pmm_init+0x1fe>
ffffffffc0201938:	6090                	ld	a2,0(s1)
}
ffffffffc020193a:	6442                	ld	s0,16(sp)
ffffffffc020193c:	60e2                	ld	ra,24(sp)
ffffffffc020193e:	64a2                	ld	s1,8(sp)
ffffffffc0201940:	6902                	ld	s2,0(sp)
    satp_physical = PADDR(satp_virtual);
ffffffffc0201942:	40c58633          	sub	a2,a1,a2
ffffffffc0201946:	00006797          	auipc	a5,0x6
ffffffffc020194a:	b2c7b923          	sd	a2,-1230(a5) # ffffffffc0207478 <satp_physical>
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc020194e:	00001517          	auipc	a0,0x1
ffffffffc0201952:	5f250513          	addi	a0,a0,1522 # ffffffffc0202f40 <default_pmm_manager+0x1c0>
}
ffffffffc0201956:	6105                	addi	sp,sp,32
    cprintf("satp virtual address: 0x%016lx\nsatp physical address: 0x%016lx\n", satp_virtual, satp_physical);
ffffffffc0201958:	f80fe06f          	j	ffffffffc02000d8 <cprintf>
    uint64_t managed_end = mem_end < mapped_end_pa ? mem_end : mapped_end_pa;
ffffffffc020195c:	873e                	mv	a4,a5
ffffffffc020195e:	b5fd                	j	ffffffffc020184c <pmm_init+0x72>
static inline int page_ref_dec(struct Page *page) {
    page->ref -= 1;
    return page->ref;
}
static inline struct Page *pa2page(uintptr_t pa) {
    if (PPN(pa) >= npage) {
ffffffffc0201960:	00033703          	ld	a4,0(t1)
ffffffffc0201964:	00c85793          	srli	a5,a6,0xc
ffffffffc0201968:	02e7f463          	bgeu	a5,a4,ffffffffc0201990 <pmm_init+0x1b6>
    pmm_manager->init_memmap(base, n);
ffffffffc020196c:	6014                	ld	a3,0(s0)
        panic("pa2page called with invalid pa");
    }
    return &pages[PPN(pa) - nbase];
ffffffffc020196e:	fff80737          	lui	a4,0xfff80
ffffffffc0201972:	973e                	add	a4,a4,a5
ffffffffc0201974:	00271793          	slli	a5,a4,0x2
ffffffffc0201978:	6108                	ld	a0,0(a0)
ffffffffc020197a:	97ba                	add	a5,a5,a4
ffffffffc020197c:	6a98                	ld	a4,16(a3)
        init_memmap(pa2page(free_start), (managed_end - free_start) / PGSIZE);
ffffffffc020197e:	410585b3          	sub	a1,a1,a6
ffffffffc0201982:	078e                	slli	a5,a5,0x3
    pmm_manager->init_memmap(base, n);
ffffffffc0201984:	81b1                	srli	a1,a1,0xc
ffffffffc0201986:	953e                	add	a0,a0,a5
ffffffffc0201988:	9702                	jalr	a4
}
ffffffffc020198a:	b751                	j	ffffffffc020190e <pmm_init+0x134>
    if (free_start < managed_end) {
ffffffffc020198c:	f8b871e3          	bgeu	a6,a1,ffffffffc020190e <pmm_init+0x134>
        panic("pa2page called with invalid pa");
ffffffffc0201990:	00001617          	auipc	a2,0x1
ffffffffc0201994:	56060613          	addi	a2,a2,1376 # ffffffffc0202ef0 <default_pmm_manager+0x170>
ffffffffc0201998:	06b00593          	li	a1,107
ffffffffc020199c:	00001517          	auipc	a0,0x1
ffffffffc02019a0:	57450513          	addi	a0,a0,1396 # ffffffffc0202f10 <default_pmm_manager+0x190>
ffffffffc02019a4:	a2ffe0ef          	jal	ra,ffffffffc02003d2 <__panic>
        panic("invalid physical memory range from device tree");
ffffffffc02019a8:	00001617          	auipc	a2,0x1
ffffffffc02019ac:	42860613          	addi	a2,a2,1064 # ffffffffc0202dd0 <default_pmm_manager+0x50>
ffffffffc02019b0:	05c00593          	li	a1,92
ffffffffc02019b4:	00001517          	auipc	a0,0x1
ffffffffc02019b8:	44c50513          	addi	a0,a0,1100 # ffffffffc0202e00 <default_pmm_manager+0x80>
ffffffffc02019bc:	a17fe0ef          	jal	ra,ffffffffc02003d2 <__panic>
        panic("kernel and page descriptors exceed managed memory");
ffffffffc02019c0:	00001617          	auipc	a2,0x1
ffffffffc02019c4:	4f860613          	addi	a2,a2,1272 # ffffffffc0202eb8 <default_pmm_manager+0x138>
ffffffffc02019c8:	07700593          	li	a1,119
ffffffffc02019cc:	00001517          	auipc	a0,0x1
ffffffffc02019d0:	43450513          	addi	a0,a0,1076 # ffffffffc0202e00 <default_pmm_manager+0x80>
ffffffffc02019d4:	9fffe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    satp_physical = PADDR(satp_virtual);
ffffffffc02019d8:	86ae                	mv	a3,a1
ffffffffc02019da:	00001617          	auipc	a2,0x1
ffffffffc02019de:	4b660613          	addi	a2,a2,1206 # ffffffffc0202e90 <default_pmm_manager+0x110>
ffffffffc02019e2:	09c00593          	li	a1,156
ffffffffc02019e6:	00001517          	auipc	a0,0x1
ffffffffc02019ea:	41a50513          	addi	a0,a0,1050 # ffffffffc0202e00 <default_pmm_manager+0x80>
ffffffffc02019ee:	9e5fe0ef          	jal	ra,ffffffffc02003d2 <__panic>
    uintptr_t pages_pa = PADDR(pages);
ffffffffc02019f2:	00001617          	auipc	a2,0x1
ffffffffc02019f6:	49e60613          	addi	a2,a2,1182 # ffffffffc0202e90 <default_pmm_manager+0x110>
ffffffffc02019fa:	07300593          	li	a1,115
ffffffffc02019fe:	00001517          	auipc	a0,0x1
ffffffffc0201a02:	40250513          	addi	a0,a0,1026 # ffffffffc0202e00 <default_pmm_manager+0x80>
ffffffffc0201a06:	9cdfe0ef          	jal	ra,ffffffffc02003d2 <__panic>
        panic("no complete physical page in the managed range");
ffffffffc0201a0a:	00001617          	auipc	a2,0x1
ffffffffc0201a0e:	45660613          	addi	a2,a2,1110 # ffffffffc0202e60 <default_pmm_manager+0xe0>
ffffffffc0201a12:	06900593          	li	a1,105
ffffffffc0201a16:	00001517          	auipc	a0,0x1
ffffffffc0201a1a:	3ea50513          	addi	a0,a0,1002 # ffffffffc0202e00 <default_pmm_manager+0x80>
ffffffffc0201a1e:	9b5fe0ef          	jal	ra,ffffffffc02003d2 <__panic>

ffffffffc0201a22 <printnum>:
 * */
static void
printnum(void (*putch)(int, void*), void *putdat,
        unsigned long long num, unsigned base, int width, int padc) {
    unsigned long long result = num;
    unsigned mod = do_div(result, base);
ffffffffc0201a22:	02069813          	slli	a6,a3,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201a26:	7179                	addi	sp,sp,-48
    unsigned mod = do_div(result, base);
ffffffffc0201a28:	02085813          	srli	a6,a6,0x20
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201a2c:	e052                	sd	s4,0(sp)
    unsigned mod = do_div(result, base);
ffffffffc0201a2e:	03067a33          	remu	s4,a2,a6
        unsigned long long num, unsigned base, int width, int padc) {
ffffffffc0201a32:	f022                	sd	s0,32(sp)
ffffffffc0201a34:	ec26                	sd	s1,24(sp)
ffffffffc0201a36:	e84a                	sd	s2,16(sp)
ffffffffc0201a38:	f406                	sd	ra,40(sp)
ffffffffc0201a3a:	e44e                	sd	s3,8(sp)
ffffffffc0201a3c:	84aa                	mv	s1,a0
ffffffffc0201a3e:	892e                	mv	s2,a1
    // first recursively print all preceding (more significant) digits
    if (num >= base) {
        printnum(putch, putdat, result, base, width - 1, padc);
    } else {
        // print any needed pad characters before first digit
        while (-- width > 0)
ffffffffc0201a40:	fff7041b          	addiw	s0,a4,-1
    unsigned mod = do_div(result, base);
ffffffffc0201a44:	2a01                	sext.w	s4,s4
    if (num >= base) {
ffffffffc0201a46:	03067e63          	bgeu	a2,a6,ffffffffc0201a82 <printnum+0x60>
ffffffffc0201a4a:	89be                	mv	s3,a5
        while (-- width > 0)
ffffffffc0201a4c:	00805763          	blez	s0,ffffffffc0201a5a <printnum+0x38>
ffffffffc0201a50:	347d                	addiw	s0,s0,-1
            putch(padc, putdat);
ffffffffc0201a52:	85ca                	mv	a1,s2
ffffffffc0201a54:	854e                	mv	a0,s3
ffffffffc0201a56:	9482                	jalr	s1
        while (-- width > 0)
ffffffffc0201a58:	fc65                	bnez	s0,ffffffffc0201a50 <printnum+0x2e>
    }
    // then print this (the least significant) digit
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201a5a:	1a02                	slli	s4,s4,0x20
ffffffffc0201a5c:	00001797          	auipc	a5,0x1
ffffffffc0201a60:	52478793          	addi	a5,a5,1316 # ffffffffc0202f80 <default_pmm_manager+0x200>
ffffffffc0201a64:	020a5a13          	srli	s4,s4,0x20
ffffffffc0201a68:	9a3e                	add	s4,s4,a5
}
ffffffffc0201a6a:	7402                	ld	s0,32(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201a6c:	000a4503          	lbu	a0,0(s4)
}
ffffffffc0201a70:	70a2                	ld	ra,40(sp)
ffffffffc0201a72:	69a2                	ld	s3,8(sp)
ffffffffc0201a74:	6a02                	ld	s4,0(sp)
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201a76:	85ca                	mv	a1,s2
ffffffffc0201a78:	87a6                	mv	a5,s1
}
ffffffffc0201a7a:	6942                	ld	s2,16(sp)
ffffffffc0201a7c:	64e2                	ld	s1,24(sp)
ffffffffc0201a7e:	6145                	addi	sp,sp,48
    putch("0123456789abcdef"[mod], putdat);
ffffffffc0201a80:	8782                	jr	a5
        printnum(putch, putdat, result, base, width - 1, padc);
ffffffffc0201a82:	03065633          	divu	a2,a2,a6
ffffffffc0201a86:	8722                	mv	a4,s0
ffffffffc0201a88:	f9bff0ef          	jal	ra,ffffffffc0201a22 <printnum>
ffffffffc0201a8c:	b7f9                	j	ffffffffc0201a5a <printnum+0x38>

ffffffffc0201a8e <vprintfmt>:
 *
 * Call this function if you are already dealing with a va_list.
 * Or you probably want printfmt() instead.
 * */
void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap) {
ffffffffc0201a8e:	7119                	addi	sp,sp,-128
ffffffffc0201a90:	f4a6                	sd	s1,104(sp)
ffffffffc0201a92:	f0ca                	sd	s2,96(sp)
ffffffffc0201a94:	ecce                	sd	s3,88(sp)
ffffffffc0201a96:	e8d2                	sd	s4,80(sp)
ffffffffc0201a98:	e4d6                	sd	s5,72(sp)
ffffffffc0201a9a:	e0da                	sd	s6,64(sp)
ffffffffc0201a9c:	fc5e                	sd	s7,56(sp)
ffffffffc0201a9e:	f06a                	sd	s10,32(sp)
ffffffffc0201aa0:	fc86                	sd	ra,120(sp)
ffffffffc0201aa2:	f8a2                	sd	s0,112(sp)
ffffffffc0201aa4:	f862                	sd	s8,48(sp)
ffffffffc0201aa6:	f466                	sd	s9,40(sp)
ffffffffc0201aa8:	ec6e                	sd	s11,24(sp)
ffffffffc0201aaa:	892a                	mv	s2,a0
ffffffffc0201aac:	84ae                	mv	s1,a1
ffffffffc0201aae:	8d32                	mv	s10,a2
ffffffffc0201ab0:	8a36                	mv	s4,a3
    register int ch, err;
    unsigned long long num;
    int base, width, precision, lflag, altflag;

    while (1) {
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201ab2:	02500993          	li	s3,37
            putch(ch, putdat);
        }

        // Process a %-escape sequence
        char padc = ' ';
        width = precision = -1;
ffffffffc0201ab6:	5b7d                	li	s6,-1
ffffffffc0201ab8:	00001a97          	auipc	s5,0x1
ffffffffc0201abc:	4fca8a93          	addi	s5,s5,1276 # ffffffffc0202fb4 <default_pmm_manager+0x234>
        case 'e':
            err = va_arg(ap, int);
            if (err < 0) {
                err = -err;
            }
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201ac0:	00001b97          	auipc	s7,0x1
ffffffffc0201ac4:	6d0b8b93          	addi	s7,s7,1744 # ffffffffc0203190 <error_string>
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201ac8:	000d4503          	lbu	a0,0(s10)
ffffffffc0201acc:	001d0413          	addi	s0,s10,1
ffffffffc0201ad0:	01350a63          	beq	a0,s3,ffffffffc0201ae4 <vprintfmt+0x56>
            if (ch == '\0') {
ffffffffc0201ad4:	c121                	beqz	a0,ffffffffc0201b14 <vprintfmt+0x86>
            putch(ch, putdat);
ffffffffc0201ad6:	85a6                	mv	a1,s1
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201ad8:	0405                	addi	s0,s0,1
            putch(ch, putdat);
ffffffffc0201ada:	9902                	jalr	s2
        while ((ch = *(unsigned char *)fmt ++) != '%') {
ffffffffc0201adc:	fff44503          	lbu	a0,-1(s0)
ffffffffc0201ae0:	ff351ae3          	bne	a0,s3,ffffffffc0201ad4 <vprintfmt+0x46>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201ae4:	00044603          	lbu	a2,0(s0)
        char padc = ' ';
ffffffffc0201ae8:	02000793          	li	a5,32
        lflag = altflag = 0;
ffffffffc0201aec:	4c81                	li	s9,0
ffffffffc0201aee:	4881                	li	a7,0
        width = precision = -1;
ffffffffc0201af0:	5c7d                	li	s8,-1
ffffffffc0201af2:	5dfd                	li	s11,-1
ffffffffc0201af4:	05500513          	li	a0,85
                if (ch < '0' || ch > '9') {
ffffffffc0201af8:	4825                	li	a6,9
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201afa:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201afe:	0ff5f593          	zext.b	a1,a1
ffffffffc0201b02:	00140d13          	addi	s10,s0,1
ffffffffc0201b06:	04b56263          	bltu	a0,a1,ffffffffc0201b4a <vprintfmt+0xbc>
ffffffffc0201b0a:	058a                	slli	a1,a1,0x2
ffffffffc0201b0c:	95d6                	add	a1,a1,s5
ffffffffc0201b0e:	4194                	lw	a3,0(a1)
ffffffffc0201b10:	96d6                	add	a3,a3,s5
ffffffffc0201b12:	8682                	jr	a3
            for (fmt --; fmt[-1] != '%'; fmt --)
                /* do nothing */;
            break;
        }
    }
}
ffffffffc0201b14:	70e6                	ld	ra,120(sp)
ffffffffc0201b16:	7446                	ld	s0,112(sp)
ffffffffc0201b18:	74a6                	ld	s1,104(sp)
ffffffffc0201b1a:	7906                	ld	s2,96(sp)
ffffffffc0201b1c:	69e6                	ld	s3,88(sp)
ffffffffc0201b1e:	6a46                	ld	s4,80(sp)
ffffffffc0201b20:	6aa6                	ld	s5,72(sp)
ffffffffc0201b22:	6b06                	ld	s6,64(sp)
ffffffffc0201b24:	7be2                	ld	s7,56(sp)
ffffffffc0201b26:	7c42                	ld	s8,48(sp)
ffffffffc0201b28:	7ca2                	ld	s9,40(sp)
ffffffffc0201b2a:	7d02                	ld	s10,32(sp)
ffffffffc0201b2c:	6de2                	ld	s11,24(sp)
ffffffffc0201b2e:	6109                	addi	sp,sp,128
ffffffffc0201b30:	8082                	ret
            padc = '0';
ffffffffc0201b32:	87b2                	mv	a5,a2
            goto reswitch;
ffffffffc0201b34:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201b38:	846a                	mv	s0,s10
ffffffffc0201b3a:	00140d13          	addi	s10,s0,1
ffffffffc0201b3e:	fdd6059b          	addiw	a1,a2,-35
ffffffffc0201b42:	0ff5f593          	zext.b	a1,a1
ffffffffc0201b46:	fcb572e3          	bgeu	a0,a1,ffffffffc0201b0a <vprintfmt+0x7c>
            putch('%', putdat);
ffffffffc0201b4a:	85a6                	mv	a1,s1
ffffffffc0201b4c:	02500513          	li	a0,37
ffffffffc0201b50:	9902                	jalr	s2
            for (fmt --; fmt[-1] != '%'; fmt --)
ffffffffc0201b52:	fff44783          	lbu	a5,-1(s0)
ffffffffc0201b56:	8d22                	mv	s10,s0
ffffffffc0201b58:	f73788e3          	beq	a5,s3,ffffffffc0201ac8 <vprintfmt+0x3a>
ffffffffc0201b5c:	ffed4783          	lbu	a5,-2(s10)
ffffffffc0201b60:	1d7d                	addi	s10,s10,-1
ffffffffc0201b62:	ff379de3          	bne	a5,s3,ffffffffc0201b5c <vprintfmt+0xce>
ffffffffc0201b66:	b78d                	j	ffffffffc0201ac8 <vprintfmt+0x3a>
                precision = precision * 10 + ch - '0';
ffffffffc0201b68:	fd060c1b          	addiw	s8,a2,-48
                ch = *fmt;
ffffffffc0201b6c:	00144603          	lbu	a2,1(s0)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201b70:	846a                	mv	s0,s10
                if (ch < '0' || ch > '9') {
ffffffffc0201b72:	fd06069b          	addiw	a3,a2,-48
                ch = *fmt;
ffffffffc0201b76:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201b7a:	02d86463          	bltu	a6,a3,ffffffffc0201ba2 <vprintfmt+0x114>
                ch = *fmt;
ffffffffc0201b7e:	00144603          	lbu	a2,1(s0)
                precision = precision * 10 + ch - '0';
ffffffffc0201b82:	002c169b          	slliw	a3,s8,0x2
ffffffffc0201b86:	0186873b          	addw	a4,a3,s8
ffffffffc0201b8a:	0017171b          	slliw	a4,a4,0x1
ffffffffc0201b8e:	9f2d                	addw	a4,a4,a1
                if (ch < '0' || ch > '9') {
ffffffffc0201b90:	fd06069b          	addiw	a3,a2,-48
            for (precision = 0; ; ++ fmt) {
ffffffffc0201b94:	0405                	addi	s0,s0,1
                precision = precision * 10 + ch - '0';
ffffffffc0201b96:	fd070c1b          	addiw	s8,a4,-48
                ch = *fmt;
ffffffffc0201b9a:	0006059b          	sext.w	a1,a2
                if (ch < '0' || ch > '9') {
ffffffffc0201b9e:	fed870e3          	bgeu	a6,a3,ffffffffc0201b7e <vprintfmt+0xf0>
            if (width < 0)
ffffffffc0201ba2:	f40ddce3          	bgez	s11,ffffffffc0201afa <vprintfmt+0x6c>
                width = precision, precision = -1;
ffffffffc0201ba6:	8de2                	mv	s11,s8
ffffffffc0201ba8:	5c7d                	li	s8,-1
ffffffffc0201baa:	bf81                	j	ffffffffc0201afa <vprintfmt+0x6c>
            if (width < 0)
ffffffffc0201bac:	fffdc693          	not	a3,s11
ffffffffc0201bb0:	96fd                	srai	a3,a3,0x3f
ffffffffc0201bb2:	00ddfdb3          	and	s11,s11,a3
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201bb6:	00144603          	lbu	a2,1(s0)
ffffffffc0201bba:	2d81                	sext.w	s11,s11
ffffffffc0201bbc:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201bbe:	bf35                	j	ffffffffc0201afa <vprintfmt+0x6c>
            precision = va_arg(ap, int);
ffffffffc0201bc0:	000a2c03          	lw	s8,0(s4)
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201bc4:	00144603          	lbu	a2,1(s0)
            precision = va_arg(ap, int);
ffffffffc0201bc8:	0a21                	addi	s4,s4,8
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201bca:	846a                	mv	s0,s10
            goto process_precision;
ffffffffc0201bcc:	bfd9                	j	ffffffffc0201ba2 <vprintfmt+0x114>
    if (lflag >= 2) {
ffffffffc0201bce:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201bd0:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201bd4:	01174463          	blt	a4,a7,ffffffffc0201bdc <vprintfmt+0x14e>
    else if (lflag) {
ffffffffc0201bd8:	1a088e63          	beqz	a7,ffffffffc0201d94 <vprintfmt+0x306>
        return va_arg(*ap, unsigned long);
ffffffffc0201bdc:	000a3603          	ld	a2,0(s4)
ffffffffc0201be0:	46c1                	li	a3,16
ffffffffc0201be2:	8a2e                	mv	s4,a1
            printnum(putch, putdat, num, base, width, padc);
ffffffffc0201be4:	2781                	sext.w	a5,a5
ffffffffc0201be6:	876e                	mv	a4,s11
ffffffffc0201be8:	85a6                	mv	a1,s1
ffffffffc0201bea:	854a                	mv	a0,s2
ffffffffc0201bec:	e37ff0ef          	jal	ra,ffffffffc0201a22 <printnum>
            break;
ffffffffc0201bf0:	bde1                	j	ffffffffc0201ac8 <vprintfmt+0x3a>
            putch(va_arg(ap, int), putdat);
ffffffffc0201bf2:	000a2503          	lw	a0,0(s4)
ffffffffc0201bf6:	85a6                	mv	a1,s1
ffffffffc0201bf8:	0a21                	addi	s4,s4,8
ffffffffc0201bfa:	9902                	jalr	s2
            break;
ffffffffc0201bfc:	b5f1                	j	ffffffffc0201ac8 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201bfe:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201c00:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201c04:	01174463          	blt	a4,a7,ffffffffc0201c0c <vprintfmt+0x17e>
    else if (lflag) {
ffffffffc0201c08:	18088163          	beqz	a7,ffffffffc0201d8a <vprintfmt+0x2fc>
        return va_arg(*ap, unsigned long);
ffffffffc0201c0c:	000a3603          	ld	a2,0(s4)
ffffffffc0201c10:	46a9                	li	a3,10
ffffffffc0201c12:	8a2e                	mv	s4,a1
ffffffffc0201c14:	bfc1                	j	ffffffffc0201be4 <vprintfmt+0x156>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201c16:	00144603          	lbu	a2,1(s0)
            altflag = 1;
ffffffffc0201c1a:	4c85                	li	s9,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201c1c:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201c1e:	bdf1                	j	ffffffffc0201afa <vprintfmt+0x6c>
            putch(ch, putdat);
ffffffffc0201c20:	85a6                	mv	a1,s1
ffffffffc0201c22:	02500513          	li	a0,37
ffffffffc0201c26:	9902                	jalr	s2
            break;
ffffffffc0201c28:	b545                	j	ffffffffc0201ac8 <vprintfmt+0x3a>
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201c2a:	00144603          	lbu	a2,1(s0)
            lflag ++;
ffffffffc0201c2e:	2885                	addiw	a7,a7,1
        switch (ch = *(unsigned char *)fmt ++) {
ffffffffc0201c30:	846a                	mv	s0,s10
            goto reswitch;
ffffffffc0201c32:	b5e1                	j	ffffffffc0201afa <vprintfmt+0x6c>
    if (lflag >= 2) {
ffffffffc0201c34:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201c36:	008a0593          	addi	a1,s4,8
    if (lflag >= 2) {
ffffffffc0201c3a:	01174463          	blt	a4,a7,ffffffffc0201c42 <vprintfmt+0x1b4>
    else if (lflag) {
ffffffffc0201c3e:	14088163          	beqz	a7,ffffffffc0201d80 <vprintfmt+0x2f2>
        return va_arg(*ap, unsigned long);
ffffffffc0201c42:	000a3603          	ld	a2,0(s4)
ffffffffc0201c46:	46a1                	li	a3,8
ffffffffc0201c48:	8a2e                	mv	s4,a1
ffffffffc0201c4a:	bf69                	j	ffffffffc0201be4 <vprintfmt+0x156>
            putch('0', putdat);
ffffffffc0201c4c:	03000513          	li	a0,48
ffffffffc0201c50:	85a6                	mv	a1,s1
ffffffffc0201c52:	e03e                	sd	a5,0(sp)
ffffffffc0201c54:	9902                	jalr	s2
            putch('x', putdat);
ffffffffc0201c56:	85a6                	mv	a1,s1
ffffffffc0201c58:	07800513          	li	a0,120
ffffffffc0201c5c:	9902                	jalr	s2
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201c5e:	0a21                	addi	s4,s4,8
            goto number;
ffffffffc0201c60:	6782                	ld	a5,0(sp)
ffffffffc0201c62:	46c1                	li	a3,16
            num = (unsigned long long)(uintptr_t)va_arg(ap, void *);
ffffffffc0201c64:	ff8a3603          	ld	a2,-8(s4)
            goto number;
ffffffffc0201c68:	bfb5                	j	ffffffffc0201be4 <vprintfmt+0x156>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201c6a:	000a3403          	ld	s0,0(s4)
ffffffffc0201c6e:	008a0713          	addi	a4,s4,8
ffffffffc0201c72:	e03a                	sd	a4,0(sp)
ffffffffc0201c74:	14040263          	beqz	s0,ffffffffc0201db8 <vprintfmt+0x32a>
            if (width > 0 && padc != '-') {
ffffffffc0201c78:	0fb05763          	blez	s11,ffffffffc0201d66 <vprintfmt+0x2d8>
ffffffffc0201c7c:	02d00693          	li	a3,45
ffffffffc0201c80:	0cd79163          	bne	a5,a3,ffffffffc0201d42 <vprintfmt+0x2b4>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201c84:	00044783          	lbu	a5,0(s0)
ffffffffc0201c88:	0007851b          	sext.w	a0,a5
ffffffffc0201c8c:	cf85                	beqz	a5,ffffffffc0201cc4 <vprintfmt+0x236>
ffffffffc0201c8e:	00140a13          	addi	s4,s0,1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201c92:	05e00413          	li	s0,94
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201c96:	000c4563          	bltz	s8,ffffffffc0201ca0 <vprintfmt+0x212>
ffffffffc0201c9a:	3c7d                	addiw	s8,s8,-1
ffffffffc0201c9c:	036c0263          	beq	s8,s6,ffffffffc0201cc0 <vprintfmt+0x232>
                    putch('?', putdat);
ffffffffc0201ca0:	85a6                	mv	a1,s1
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201ca2:	0e0c8e63          	beqz	s9,ffffffffc0201d9e <vprintfmt+0x310>
ffffffffc0201ca6:	3781                	addiw	a5,a5,-32
ffffffffc0201ca8:	0ef47b63          	bgeu	s0,a5,ffffffffc0201d9e <vprintfmt+0x310>
                    putch('?', putdat);
ffffffffc0201cac:	03f00513          	li	a0,63
ffffffffc0201cb0:	9902                	jalr	s2
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201cb2:	000a4783          	lbu	a5,0(s4)
ffffffffc0201cb6:	3dfd                	addiw	s11,s11,-1
ffffffffc0201cb8:	0a05                	addi	s4,s4,1
ffffffffc0201cba:	0007851b          	sext.w	a0,a5
ffffffffc0201cbe:	ffe1                	bnez	a5,ffffffffc0201c96 <vprintfmt+0x208>
            for (; width > 0; width --) {
ffffffffc0201cc0:	01b05963          	blez	s11,ffffffffc0201cd2 <vprintfmt+0x244>
ffffffffc0201cc4:	3dfd                	addiw	s11,s11,-1
                putch(' ', putdat);
ffffffffc0201cc6:	85a6                	mv	a1,s1
ffffffffc0201cc8:	02000513          	li	a0,32
ffffffffc0201ccc:	9902                	jalr	s2
            for (; width > 0; width --) {
ffffffffc0201cce:	fe0d9be3          	bnez	s11,ffffffffc0201cc4 <vprintfmt+0x236>
            if ((p = va_arg(ap, char *)) == NULL) {
ffffffffc0201cd2:	6a02                	ld	s4,0(sp)
ffffffffc0201cd4:	bbd5                	j	ffffffffc0201ac8 <vprintfmt+0x3a>
    if (lflag >= 2) {
ffffffffc0201cd6:	4705                	li	a4,1
            precision = va_arg(ap, int);
ffffffffc0201cd8:	008a0c93          	addi	s9,s4,8
    if (lflag >= 2) {
ffffffffc0201cdc:	01174463          	blt	a4,a7,ffffffffc0201ce4 <vprintfmt+0x256>
    else if (lflag) {
ffffffffc0201ce0:	08088d63          	beqz	a7,ffffffffc0201d7a <vprintfmt+0x2ec>
        return va_arg(*ap, long);
ffffffffc0201ce4:	000a3403          	ld	s0,0(s4)
            if ((long long)num < 0) {
ffffffffc0201ce8:	0a044d63          	bltz	s0,ffffffffc0201da2 <vprintfmt+0x314>
            num = getint(&ap, lflag);
ffffffffc0201cec:	8622                	mv	a2,s0
ffffffffc0201cee:	8a66                	mv	s4,s9
ffffffffc0201cf0:	46a9                	li	a3,10
ffffffffc0201cf2:	bdcd                	j	ffffffffc0201be4 <vprintfmt+0x156>
            err = va_arg(ap, int);
ffffffffc0201cf4:	000a2783          	lw	a5,0(s4)
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201cf8:	4719                	li	a4,6
            err = va_arg(ap, int);
ffffffffc0201cfa:	0a21                	addi	s4,s4,8
            if (err < 0) {
ffffffffc0201cfc:	41f7d69b          	sraiw	a3,a5,0x1f
ffffffffc0201d00:	8fb5                	xor	a5,a5,a3
ffffffffc0201d02:	40d786bb          	subw	a3,a5,a3
            if (err > MAXERROR || (p = error_string[err]) == NULL) {
ffffffffc0201d06:	02d74163          	blt	a4,a3,ffffffffc0201d28 <vprintfmt+0x29a>
ffffffffc0201d0a:	00369793          	slli	a5,a3,0x3
ffffffffc0201d0e:	97de                	add	a5,a5,s7
ffffffffc0201d10:	639c                	ld	a5,0(a5)
ffffffffc0201d12:	cb99                	beqz	a5,ffffffffc0201d28 <vprintfmt+0x29a>
                printfmt(putch, putdat, "%s", p);
ffffffffc0201d14:	86be                	mv	a3,a5
ffffffffc0201d16:	00001617          	auipc	a2,0x1
ffffffffc0201d1a:	29a60613          	addi	a2,a2,666 # ffffffffc0202fb0 <default_pmm_manager+0x230>
ffffffffc0201d1e:	85a6                	mv	a1,s1
ffffffffc0201d20:	854a                	mv	a0,s2
ffffffffc0201d22:	0ce000ef          	jal	ra,ffffffffc0201df0 <printfmt>
ffffffffc0201d26:	b34d                	j	ffffffffc0201ac8 <vprintfmt+0x3a>
                printfmt(putch, putdat, "error %d", err);
ffffffffc0201d28:	00001617          	auipc	a2,0x1
ffffffffc0201d2c:	27860613          	addi	a2,a2,632 # ffffffffc0202fa0 <default_pmm_manager+0x220>
ffffffffc0201d30:	85a6                	mv	a1,s1
ffffffffc0201d32:	854a                	mv	a0,s2
ffffffffc0201d34:	0bc000ef          	jal	ra,ffffffffc0201df0 <printfmt>
ffffffffc0201d38:	bb41                	j	ffffffffc0201ac8 <vprintfmt+0x3a>
                p = "(null)";
ffffffffc0201d3a:	00001417          	auipc	s0,0x1
ffffffffc0201d3e:	25e40413          	addi	s0,s0,606 # ffffffffc0202f98 <default_pmm_manager+0x218>
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201d42:	85e2                	mv	a1,s8
ffffffffc0201d44:	8522                	mv	a0,s0
ffffffffc0201d46:	e43e                	sd	a5,8(sp)
ffffffffc0201d48:	200000ef          	jal	ra,ffffffffc0201f48 <strnlen>
ffffffffc0201d4c:	40ad8dbb          	subw	s11,s11,a0
ffffffffc0201d50:	01b05b63          	blez	s11,ffffffffc0201d66 <vprintfmt+0x2d8>
                    putch(padc, putdat);
ffffffffc0201d54:	67a2                	ld	a5,8(sp)
ffffffffc0201d56:	00078a1b          	sext.w	s4,a5
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201d5a:	3dfd                	addiw	s11,s11,-1
                    putch(padc, putdat);
ffffffffc0201d5c:	85a6                	mv	a1,s1
ffffffffc0201d5e:	8552                	mv	a0,s4
ffffffffc0201d60:	9902                	jalr	s2
                for (width -= strnlen(p, precision); width > 0; width --) {
ffffffffc0201d62:	fe0d9ce3          	bnez	s11,ffffffffc0201d5a <vprintfmt+0x2cc>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201d66:	00044783          	lbu	a5,0(s0)
ffffffffc0201d6a:	00140a13          	addi	s4,s0,1
ffffffffc0201d6e:	0007851b          	sext.w	a0,a5
ffffffffc0201d72:	d3a5                	beqz	a5,ffffffffc0201cd2 <vprintfmt+0x244>
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201d74:	05e00413          	li	s0,94
ffffffffc0201d78:	bf39                	j	ffffffffc0201c96 <vprintfmt+0x208>
        return va_arg(*ap, int);
ffffffffc0201d7a:	000a2403          	lw	s0,0(s4)
ffffffffc0201d7e:	b7ad                	j	ffffffffc0201ce8 <vprintfmt+0x25a>
        return va_arg(*ap, unsigned int);
ffffffffc0201d80:	000a6603          	lwu	a2,0(s4)
ffffffffc0201d84:	46a1                	li	a3,8
ffffffffc0201d86:	8a2e                	mv	s4,a1
ffffffffc0201d88:	bdb1                	j	ffffffffc0201be4 <vprintfmt+0x156>
ffffffffc0201d8a:	000a6603          	lwu	a2,0(s4)
ffffffffc0201d8e:	46a9                	li	a3,10
ffffffffc0201d90:	8a2e                	mv	s4,a1
ffffffffc0201d92:	bd89                	j	ffffffffc0201be4 <vprintfmt+0x156>
ffffffffc0201d94:	000a6603          	lwu	a2,0(s4)
ffffffffc0201d98:	46c1                	li	a3,16
ffffffffc0201d9a:	8a2e                	mv	s4,a1
ffffffffc0201d9c:	b5a1                	j	ffffffffc0201be4 <vprintfmt+0x156>
                    putch(ch, putdat);
ffffffffc0201d9e:	9902                	jalr	s2
ffffffffc0201da0:	bf09                	j	ffffffffc0201cb2 <vprintfmt+0x224>
                putch('-', putdat);
ffffffffc0201da2:	85a6                	mv	a1,s1
ffffffffc0201da4:	02d00513          	li	a0,45
ffffffffc0201da8:	e03e                	sd	a5,0(sp)
ffffffffc0201daa:	9902                	jalr	s2
                num = -(long long)num;
ffffffffc0201dac:	6782                	ld	a5,0(sp)
ffffffffc0201dae:	8a66                	mv	s4,s9
ffffffffc0201db0:	40800633          	neg	a2,s0
ffffffffc0201db4:	46a9                	li	a3,10
ffffffffc0201db6:	b53d                	j	ffffffffc0201be4 <vprintfmt+0x156>
            if (width > 0 && padc != '-') {
ffffffffc0201db8:	03b05163          	blez	s11,ffffffffc0201dda <vprintfmt+0x34c>
ffffffffc0201dbc:	02d00693          	li	a3,45
ffffffffc0201dc0:	f6d79de3          	bne	a5,a3,ffffffffc0201d3a <vprintfmt+0x2ac>
                p = "(null)";
ffffffffc0201dc4:	00001417          	auipc	s0,0x1
ffffffffc0201dc8:	1d440413          	addi	s0,s0,468 # ffffffffc0202f98 <default_pmm_manager+0x218>
            for (; (ch = *p ++) != '\0' && (precision < 0 || -- precision >= 0); width --) {
ffffffffc0201dcc:	02800793          	li	a5,40
ffffffffc0201dd0:	02800513          	li	a0,40
ffffffffc0201dd4:	00140a13          	addi	s4,s0,1
ffffffffc0201dd8:	bd6d                	j	ffffffffc0201c92 <vprintfmt+0x204>
ffffffffc0201dda:	00001a17          	auipc	s4,0x1
ffffffffc0201dde:	1bfa0a13          	addi	s4,s4,447 # ffffffffc0202f99 <default_pmm_manager+0x219>
ffffffffc0201de2:	02800513          	li	a0,40
ffffffffc0201de6:	02800793          	li	a5,40
                if (altflag && (ch < ' ' || ch > '~')) {
ffffffffc0201dea:	05e00413          	li	s0,94
ffffffffc0201dee:	b565                	j	ffffffffc0201c96 <vprintfmt+0x208>

ffffffffc0201df0 <printfmt>:
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201df0:	715d                	addi	sp,sp,-80
    va_start(ap, fmt);
ffffffffc0201df2:	02810313          	addi	t1,sp,40
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201df6:	f436                	sd	a3,40(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201df8:	869a                	mv	a3,t1
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...) {
ffffffffc0201dfa:	ec06                	sd	ra,24(sp)
ffffffffc0201dfc:	f83a                	sd	a4,48(sp)
ffffffffc0201dfe:	fc3e                	sd	a5,56(sp)
ffffffffc0201e00:	e0c2                	sd	a6,64(sp)
ffffffffc0201e02:	e4c6                	sd	a7,72(sp)
    va_start(ap, fmt);
ffffffffc0201e04:	e41a                	sd	t1,8(sp)
    vprintfmt(putch, putdat, fmt, ap);
ffffffffc0201e06:	c89ff0ef          	jal	ra,ffffffffc0201a8e <vprintfmt>
}
ffffffffc0201e0a:	60e2                	ld	ra,24(sp)
ffffffffc0201e0c:	6161                	addi	sp,sp,80
ffffffffc0201e0e:	8082                	ret

ffffffffc0201e10 <readline>:
 * The readline() function returns the text of the line read. If some errors
 * are happened, NULL is returned. The return value is a global variable,
 * thus it should be copied before it is used.
 * */
char *
readline(const char *prompt) {
ffffffffc0201e10:	715d                	addi	sp,sp,-80
ffffffffc0201e12:	e486                	sd	ra,72(sp)
ffffffffc0201e14:	e0a6                	sd	s1,64(sp)
ffffffffc0201e16:	fc4a                	sd	s2,56(sp)
ffffffffc0201e18:	f84e                	sd	s3,48(sp)
ffffffffc0201e1a:	f452                	sd	s4,40(sp)
ffffffffc0201e1c:	f056                	sd	s5,32(sp)
ffffffffc0201e1e:	ec5a                	sd	s6,24(sp)
ffffffffc0201e20:	e85e                	sd	s7,16(sp)
    if (prompt != NULL) {
ffffffffc0201e22:	c901                	beqz	a0,ffffffffc0201e32 <readline+0x22>
ffffffffc0201e24:	85aa                	mv	a1,a0
        cprintf("%s", prompt);
ffffffffc0201e26:	00001517          	auipc	a0,0x1
ffffffffc0201e2a:	18a50513          	addi	a0,a0,394 # ffffffffc0202fb0 <default_pmm_manager+0x230>
ffffffffc0201e2e:	aaafe0ef          	jal	ra,ffffffffc02000d8 <cprintf>
readline(const char *prompt) {
ffffffffc0201e32:	4481                	li	s1,0
    while (1) {
        c = getchar();
        if (c < 0) {
            return NULL;
        }
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201e34:	497d                	li	s2,31
            cputchar(c);
            buf[i ++] = c;
        }
        else if (c == '\b' && i > 0) {
ffffffffc0201e36:	49a1                	li	s3,8
            cputchar(c);
            i --;
        }
        else if (c == '\n' || c == '\r') {
ffffffffc0201e38:	4aa9                	li	s5,10
ffffffffc0201e3a:	4b35                	li	s6,13
            buf[i ++] = c;
ffffffffc0201e3c:	00005b97          	auipc	s7,0x5
ffffffffc0201e40:	204b8b93          	addi	s7,s7,516 # ffffffffc0207040 <buf>
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201e44:	3fe00a13          	li	s4,1022
        c = getchar();
ffffffffc0201e48:	b08fe0ef          	jal	ra,ffffffffc0200150 <getchar>
        if (c < 0) {
ffffffffc0201e4c:	00054a63          	bltz	a0,ffffffffc0201e60 <readline+0x50>
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201e50:	00a95a63          	bge	s2,a0,ffffffffc0201e64 <readline+0x54>
ffffffffc0201e54:	029a5263          	bge	s4,s1,ffffffffc0201e78 <readline+0x68>
        c = getchar();
ffffffffc0201e58:	af8fe0ef          	jal	ra,ffffffffc0200150 <getchar>
        if (c < 0) {
ffffffffc0201e5c:	fe055ae3          	bgez	a0,ffffffffc0201e50 <readline+0x40>
            return NULL;
ffffffffc0201e60:	4501                	li	a0,0
ffffffffc0201e62:	a091                	j	ffffffffc0201ea6 <readline+0x96>
        else if (c == '\b' && i > 0) {
ffffffffc0201e64:	03351463          	bne	a0,s3,ffffffffc0201e8c <readline+0x7c>
ffffffffc0201e68:	e8a9                	bnez	s1,ffffffffc0201eba <readline+0xaa>
        c = getchar();
ffffffffc0201e6a:	ae6fe0ef          	jal	ra,ffffffffc0200150 <getchar>
        if (c < 0) {
ffffffffc0201e6e:	fe0549e3          	bltz	a0,ffffffffc0201e60 <readline+0x50>
        else if (c >= ' ' && i < BUFSIZE - 1) {
ffffffffc0201e72:	fea959e3          	bge	s2,a0,ffffffffc0201e64 <readline+0x54>
ffffffffc0201e76:	4481                	li	s1,0
            cputchar(c);
ffffffffc0201e78:	e42a                	sd	a0,8(sp)
ffffffffc0201e7a:	a94fe0ef          	jal	ra,ffffffffc020010e <cputchar>
            buf[i ++] = c;
ffffffffc0201e7e:	6522                	ld	a0,8(sp)
ffffffffc0201e80:	009b87b3          	add	a5,s7,s1
ffffffffc0201e84:	2485                	addiw	s1,s1,1
ffffffffc0201e86:	00a78023          	sb	a0,0(a5)
ffffffffc0201e8a:	bf7d                	j	ffffffffc0201e48 <readline+0x38>
        else if (c == '\n' || c == '\r') {
ffffffffc0201e8c:	01550463          	beq	a0,s5,ffffffffc0201e94 <readline+0x84>
ffffffffc0201e90:	fb651ce3          	bne	a0,s6,ffffffffc0201e48 <readline+0x38>
            cputchar(c);
ffffffffc0201e94:	a7afe0ef          	jal	ra,ffffffffc020010e <cputchar>
            buf[i] = '\0';
ffffffffc0201e98:	00005517          	auipc	a0,0x5
ffffffffc0201e9c:	1a850513          	addi	a0,a0,424 # ffffffffc0207040 <buf>
ffffffffc0201ea0:	94aa                	add	s1,s1,a0
ffffffffc0201ea2:	00048023          	sb	zero,0(s1)
            return buf;
        }
    }
}
ffffffffc0201ea6:	60a6                	ld	ra,72(sp)
ffffffffc0201ea8:	6486                	ld	s1,64(sp)
ffffffffc0201eaa:	7962                	ld	s2,56(sp)
ffffffffc0201eac:	79c2                	ld	s3,48(sp)
ffffffffc0201eae:	7a22                	ld	s4,40(sp)
ffffffffc0201eb0:	7a82                	ld	s5,32(sp)
ffffffffc0201eb2:	6b62                	ld	s6,24(sp)
ffffffffc0201eb4:	6bc2                	ld	s7,16(sp)
ffffffffc0201eb6:	6161                	addi	sp,sp,80
ffffffffc0201eb8:	8082                	ret
            cputchar(c);
ffffffffc0201eba:	4521                	li	a0,8
ffffffffc0201ebc:	a52fe0ef          	jal	ra,ffffffffc020010e <cputchar>
            i --;
ffffffffc0201ec0:	34fd                	addiw	s1,s1,-1
ffffffffc0201ec2:	b759                	j	ffffffffc0201e48 <readline+0x38>

ffffffffc0201ec4 <sbi_console_putchar>:
uint64_t SBI_REMOTE_SFENCE_VMA_ASID = 7;
uint64_t SBI_SHUTDOWN = 8;

uint64_t sbi_call(uint64_t sbi_type, uint64_t arg0, uint64_t arg1, uint64_t arg2) {
    uint64_t ret_val;
    __asm__ volatile (
ffffffffc0201ec4:	4781                	li	a5,0
ffffffffc0201ec6:	00005717          	auipc	a4,0x5
ffffffffc0201eca:	15273703          	ld	a4,338(a4) # ffffffffc0207018 <SBI_CONSOLE_PUTCHAR>
ffffffffc0201ece:	88ba                	mv	a7,a4
ffffffffc0201ed0:	852a                	mv	a0,a0
ffffffffc0201ed2:	85be                	mv	a1,a5
ffffffffc0201ed4:	863e                	mv	a2,a5
ffffffffc0201ed6:	00000073          	ecall
ffffffffc0201eda:	87aa                	mv	a5,a0
    return ret_val;
}

void sbi_console_putchar(unsigned char ch) {
    sbi_call(SBI_CONSOLE_PUTCHAR, ch, 0, 0);
}
ffffffffc0201edc:	8082                	ret

ffffffffc0201ede <sbi_set_timer>:
    __asm__ volatile (
ffffffffc0201ede:	4781                	li	a5,0
ffffffffc0201ee0:	00005717          	auipc	a4,0x5
ffffffffc0201ee4:	5b073703          	ld	a4,1456(a4) # ffffffffc0207490 <SBI_SET_TIMER>
ffffffffc0201ee8:	88ba                	mv	a7,a4
ffffffffc0201eea:	852a                	mv	a0,a0
ffffffffc0201eec:	85be                	mv	a1,a5
ffffffffc0201eee:	863e                	mv	a2,a5
ffffffffc0201ef0:	00000073          	ecall
ffffffffc0201ef4:	87aa                	mv	a5,a0

void sbi_set_timer(unsigned long long stime_value) {
    sbi_call(SBI_SET_TIMER, stime_value, 0, 0);
}
ffffffffc0201ef6:	8082                	ret

ffffffffc0201ef8 <sbi_console_getchar>:
    __asm__ volatile (
ffffffffc0201ef8:	4501                	li	a0,0
ffffffffc0201efa:	00005797          	auipc	a5,0x5
ffffffffc0201efe:	1167b783          	ld	a5,278(a5) # ffffffffc0207010 <SBI_CONSOLE_GETCHAR>
ffffffffc0201f02:	88be                	mv	a7,a5
ffffffffc0201f04:	852a                	mv	a0,a0
ffffffffc0201f06:	85aa                	mv	a1,a0
ffffffffc0201f08:	862a                	mv	a2,a0
ffffffffc0201f0a:	00000073          	ecall
ffffffffc0201f0e:	852a                	mv	a0,a0

int sbi_console_getchar(void) {
    return sbi_call(SBI_CONSOLE_GETCHAR, 0, 0, 0);
}
ffffffffc0201f10:	2501                	sext.w	a0,a0
ffffffffc0201f12:	8082                	ret

ffffffffc0201f14 <sbi_shutdown>:
    __asm__ volatile (
ffffffffc0201f14:	4781                	li	a5,0
ffffffffc0201f16:	00005717          	auipc	a4,0x5
ffffffffc0201f1a:	10a73703          	ld	a4,266(a4) # ffffffffc0207020 <SBI_SHUTDOWN>
ffffffffc0201f1e:	88ba                	mv	a7,a4
ffffffffc0201f20:	853e                	mv	a0,a5
ffffffffc0201f22:	85be                	mv	a1,a5
ffffffffc0201f24:	863e                	mv	a2,a5
ffffffffc0201f26:	00000073          	ecall
ffffffffc0201f2a:	87aa                	mv	a5,a0

void sbi_shutdown(void)
{
	sbi_call(SBI_SHUTDOWN, 0, 0, 0);
ffffffffc0201f2c:	8082                	ret

ffffffffc0201f2e <strlen>:
 * The strlen() function returns the length of string @s.
 * */
size_t
strlen(const char *s) {
    size_t cnt = 0;
    while (*s ++ != '\0') {
ffffffffc0201f2e:	00054783          	lbu	a5,0(a0)
strlen(const char *s) {
ffffffffc0201f32:	872a                	mv	a4,a0
    size_t cnt = 0;
ffffffffc0201f34:	4501                	li	a0,0
    while (*s ++ != '\0') {
ffffffffc0201f36:	cb81                	beqz	a5,ffffffffc0201f46 <strlen+0x18>
        cnt ++;
ffffffffc0201f38:	0505                	addi	a0,a0,1
    while (*s ++ != '\0') {
ffffffffc0201f3a:	00a707b3          	add	a5,a4,a0
ffffffffc0201f3e:	0007c783          	lbu	a5,0(a5)
ffffffffc0201f42:	fbfd                	bnez	a5,ffffffffc0201f38 <strlen+0xa>
ffffffffc0201f44:	8082                	ret
    }
    return cnt;
}
ffffffffc0201f46:	8082                	ret

ffffffffc0201f48 <strnlen>:
 * @len if there is no '\0' character among the first @len characters
 * pointed by @s.
 * */
size_t
strnlen(const char *s, size_t len) {
    size_t cnt = 0;
ffffffffc0201f48:	4781                	li	a5,0
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201f4a:	e589                	bnez	a1,ffffffffc0201f54 <strnlen+0xc>
ffffffffc0201f4c:	a811                	j	ffffffffc0201f60 <strnlen+0x18>
        cnt ++;
ffffffffc0201f4e:	0785                	addi	a5,a5,1
    while (cnt < len && *s ++ != '\0') {
ffffffffc0201f50:	00f58863          	beq	a1,a5,ffffffffc0201f60 <strnlen+0x18>
ffffffffc0201f54:	00f50733          	add	a4,a0,a5
ffffffffc0201f58:	00074703          	lbu	a4,0(a4)
ffffffffc0201f5c:	fb6d                	bnez	a4,ffffffffc0201f4e <strnlen+0x6>
ffffffffc0201f5e:	85be                	mv	a1,a5
    }
    return cnt;
}
ffffffffc0201f60:	852e                	mv	a0,a1
ffffffffc0201f62:	8082                	ret

ffffffffc0201f64 <strcmp>:
int
strcmp(const char *s1, const char *s2) {
#ifdef __HAVE_ARCH_STRCMP
    return __strcmp(s1, s2);
#else
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201f64:	00054783          	lbu	a5,0(a0)
        s1 ++, s2 ++;
    }
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201f68:	0005c703          	lbu	a4,0(a1)
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201f6c:	cb89                	beqz	a5,ffffffffc0201f7e <strcmp+0x1a>
        s1 ++, s2 ++;
ffffffffc0201f6e:	0505                	addi	a0,a0,1
ffffffffc0201f70:	0585                	addi	a1,a1,1
    while (*s1 != '\0' && *s1 == *s2) {
ffffffffc0201f72:	fee789e3          	beq	a5,a4,ffffffffc0201f64 <strcmp>
    return (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201f76:	0007851b          	sext.w	a0,a5
#endif /* __HAVE_ARCH_STRCMP */
}
ffffffffc0201f7a:	9d19                	subw	a0,a0,a4
ffffffffc0201f7c:	8082                	ret
ffffffffc0201f7e:	4501                	li	a0,0
ffffffffc0201f80:	bfed                	j	ffffffffc0201f7a <strcmp+0x16>

ffffffffc0201f82 <strncmp>:
 * the characters differ, until a terminating null-character is reached, or
 * until @n characters match in both strings, whichever happens first.
 * */
int
strncmp(const char *s1, const char *s2, size_t n) {
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201f82:	c20d                	beqz	a2,ffffffffc0201fa4 <strncmp+0x22>
ffffffffc0201f84:	962e                	add	a2,a2,a1
ffffffffc0201f86:	a031                	j	ffffffffc0201f92 <strncmp+0x10>
        n --, s1 ++, s2 ++;
ffffffffc0201f88:	0505                	addi	a0,a0,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201f8a:	00e79a63          	bne	a5,a4,ffffffffc0201f9e <strncmp+0x1c>
ffffffffc0201f8e:	00b60b63          	beq	a2,a1,ffffffffc0201fa4 <strncmp+0x22>
ffffffffc0201f92:	00054783          	lbu	a5,0(a0)
        n --, s1 ++, s2 ++;
ffffffffc0201f96:	0585                	addi	a1,a1,1
    while (n > 0 && *s1 != '\0' && *s1 == *s2) {
ffffffffc0201f98:	fff5c703          	lbu	a4,-1(a1)
ffffffffc0201f9c:	f7f5                	bnez	a5,ffffffffc0201f88 <strncmp+0x6>
    }
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201f9e:	40e7853b          	subw	a0,a5,a4
}
ffffffffc0201fa2:	8082                	ret
    return (n == 0) ? 0 : (int)((unsigned char)*s1 - (unsigned char)*s2);
ffffffffc0201fa4:	4501                	li	a0,0
ffffffffc0201fa6:	8082                	ret

ffffffffc0201fa8 <strchr>:
 * The strchr() function returns a pointer to the first occurrence of
 * character in @s. If the value is not found, the function returns 'NULL'.
 * */
char *
strchr(const char *s, char c) {
    while (*s != '\0') {
ffffffffc0201fa8:	00054783          	lbu	a5,0(a0)
ffffffffc0201fac:	c799                	beqz	a5,ffffffffc0201fba <strchr+0x12>
        if (*s == c) {
ffffffffc0201fae:	00f58763          	beq	a1,a5,ffffffffc0201fbc <strchr+0x14>
    while (*s != '\0') {
ffffffffc0201fb2:	00154783          	lbu	a5,1(a0)
            return (char *)s;
        }
        s ++;
ffffffffc0201fb6:	0505                	addi	a0,a0,1
    while (*s != '\0') {
ffffffffc0201fb8:	fbfd                	bnez	a5,ffffffffc0201fae <strchr+0x6>
    }
    return NULL;
ffffffffc0201fba:	4501                	li	a0,0
}
ffffffffc0201fbc:	8082                	ret

ffffffffc0201fbe <memset>:
memset(void *s, char c, size_t n) {
#ifdef __HAVE_ARCH_MEMSET
    return __memset(s, c, n);
#else
    char *p = s;
    while (n -- > 0) {
ffffffffc0201fbe:	ca01                	beqz	a2,ffffffffc0201fce <memset+0x10>
ffffffffc0201fc0:	962a                	add	a2,a2,a0
    char *p = s;
ffffffffc0201fc2:	87aa                	mv	a5,a0
        *p ++ = c;
ffffffffc0201fc4:	0785                	addi	a5,a5,1
ffffffffc0201fc6:	feb78fa3          	sb	a1,-1(a5)
    while (n -- > 0) {
ffffffffc0201fca:	fec79de3          	bne	a5,a2,ffffffffc0201fc4 <memset+0x6>
    }
    return s;
#endif /* __HAVE_ARCH_MEMSET */
}
ffffffffc0201fce:	8082                	ret
