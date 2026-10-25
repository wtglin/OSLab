#include <buddy_pmm.h>
#include <list.h>
#include <pmm.h>
#include <stdio.h>

/*
 * 伙伴系统（Buddy System）物理内存分配器。
 *
 * 物理页按照 2 的幂次组织成块：order 为 k 的块恰好包含 2^k 个连续页。
 * free_area[k] 保存所有当前空闲、阶数为 k 的块，块首页通过 page_link
 * 挂入双向链表，并用 property 记录该块的阶数。
 *
 * 分配时若目标阶数没有空闲块，就从更大的块中逐层对半拆分；释放时若
 * 相邻的“伙伴块”也空闲且阶数相同，则合并成更大的块，直到无法继续。
 */

/* 最多支持 order 10，即单个连续块最大为 2^10 = 1024 页。 */
#define MAX_ORDER 11

/* 按阶数组织的空闲块链表；下标同时也是块的阶数。 */
static free_area_t free_area[MAX_ORDER];
/* 当前所有阶数空闲块包含的物理页总数。 */
static size_t nr_free = 0;

/*
 * 将请求页数向上取整为 2 的幂次，并返回对应的阶数。
 * 例如 n = 1/2/3/4 时，结果依次为 0/1/2/2。
 */
static size_t
pages_to_order(size_t n) {
    size_t order = 0;
    size_t pages = 1;

    while (pages < n) {
        pages <<= 1;
        order ++;
    }
    return order;
}

/*
 * 在 [page, page + remaining) 中，找出从 page 开始能够形成的最大块阶数。
 * 除了不能超过剩余页数外，起始物理页号还必须按块大小对齐，否则该块无法
 * 与伙伴块正确配对。
 */
static size_t
largest_aligned_order(struct Page *page, size_t remaining) {
    size_t order = MAX_ORDER - 1;
    size_t pfn = page2ppn(page);

    while (order > 0 &&
           ((1U << order) > remaining || (pfn & ((1U << order) - 1)))) {
        order --;
    }
    return order;
}

/*
 * 将一个空闲块插入 free_area[order]。
 * 链表按物理地址升序维护，既便于检查，也让空闲块顺序保持稳定。
 */
static void
add_free_block(struct Page *base, size_t order) {
    list_entry_t *head = &(free_area[order].free_list);
    list_entry_t *le = list_next(head);
    while (le != head) {
        struct Page *page = le2page(le, page_link);
        assert(page != base);
        if (page2pa(base) < page2pa(page)) {
            break;
        }
        le = list_next(le);
    }

    base->property = order;
    SetPageProperty(base);
    list_add_before(le, &(base->page_link));
    free_area[order].nr_free += 1U << order;
}

/*
 * 从 free_area[order] 中摘下一个空闲块，并清除块首页的空闲标记。
 * 调用者应保证 base 确实位于对应阶数的空闲链表中。
 */
static struct Page *
remove_free_block(struct Page *base, size_t order) {
    list_del(&(base->page_link));
    free_area[order].nr_free -= 1U << order;
    ClearPageProperty(base);
    base->property = 0;
    return base;
}

/*
 * 计算 base 在指定阶数下的伙伴块。
 * 同阶伙伴的起始页号只有第 order 位不同，因此可通过异或直接求得；
 * 若伙伴页号超出物理内存范围，则返回 NULL。
 */
static struct Page *
find_buddy(struct Page *base, size_t order) {
    size_t buddy_pfn = page2ppn(base) ^ (1U << order);

    if (buddy_pfn < nbase || buddy_pfn >= npage) {
        return NULL;
    }
    return pa2page(buddy_pfn << PGSHIFT);
}

/* 初始化所有阶数的空闲链表和全局空闲页计数。 */
static void
buddy_init(void) {
    for (size_t order = 0; order < MAX_ORDER; order ++) {
        list_init(&(free_area[order].free_list));
        free_area[order].nr_free = 0;
    }
    nr_free = 0;
}

/*
 * 把一段可用的连续物理页加入伙伴系统。
 * 先清除这些页的保留标记和旧状态，再将区间尽量拆成“起始页号对齐”的
 * 2 的幂次块；这样每个块都能通过异或找到合法的伙伴。
 */
static void
buddy_init_memmap(struct Page *base, size_t n) {
    assert(n > 0);

    struct Page *page = base;
    for (; page != base + n; page ++) {
        assert(PageReserved(page));
        page->flags = 0;
        page->property = 0;
        set_page_ref(page, 0);
    }

    size_t remaining = n;
    page = base;
    while (remaining > 0) {
        size_t order = largest_aligned_order(page, remaining);

        add_free_block(page, order);
        page += 1U << order;
        remaining -= 1U << order;
    }
    nr_free += n;
}

/*
 * 分配至少 n 个连续物理页，实际分配大小为不小于 n 的最小 2 的幂次。
 * 查找顺序是从目标阶数向上寻找第一个非空链表；找到较大块后，从高位向
 * 低位逐次对半拆分，把后半块放回空闲链表，前半块继续用于分配。
 */
static struct Page *
buddy_alloc_pages(size_t n) {
    assert(n > 0);

    if (n > (1U << (MAX_ORDER - 1))) {
        return NULL;
    }
    size_t target_order = pages_to_order(n);

    size_t order = target_order;
    while (order < MAX_ORDER &&
           list_empty(&(free_area[order].free_list))) {
        order ++;
    }
    if (order == MAX_ORDER) {
        return NULL;
    }

    struct Page *page = le2page(
        list_next(&(free_area[order].free_list)), page_link);
    remove_free_block(page, order);

    while (order > target_order) {
        order --;
        struct Page *buddy = page + (1U << order);
        add_free_block(buddy, order);
    }

    ClearPageProperty(page);
    page->property = 0;
    nr_free -= 1U << target_order;
    return page;
}

/*
 * 释放以 base 为首、长度为 n 的连续页。
 * 释放大小会向上取整到 2 的幂次；随后反复检查同阶伙伴是否空闲，若满足
 * 条件就移除伙伴并与当前块合并，直到伙伴不存在或阶数达到上限。
 */
static void
buddy_free_pages(struct Page *base, size_t n) {
    assert(n > 0);
    assert(base != NULL);

    assert(n <= (1U << (MAX_ORDER - 1)));
    size_t order = pages_to_order(n);

    struct Page *page = base;
    for (; page != base + n; page ++) {
        assert(!PageReserved(page));
        assert(!PageProperty(page));
        page->flags = 0;
        page->property = 0;
        set_page_ref(page, 0);
    }

    nr_free += 1U << order;
    while (order < MAX_ORDER - 1) {
        struct Page *buddy = find_buddy(base, order);
        if (buddy == NULL || !PageProperty(buddy) ||
            buddy->property != order) {
            break;
        }

        list_entry_t *le = &(free_area[order].free_list);
        while ((le = list_next(le)) != &(free_area[order].free_list)) {
            if (le2page(le, page_link) == buddy) {
                break;
            }
        }
        if (le == &(free_area[order].free_list)) {
            break;
        }

        remove_free_block(buddy, order);
        if (buddy < base) {
            base = buddy;
        }
        order ++;
    }

    add_free_block(base, order);
}

/* 返回当前伙伴系统中空闲物理页的总数。 */
static size_t
buddy_nr_free_pages(void) {
    return nr_free;
}

/*
 * 伙伴系统自检：覆盖基本分配/释放、非 2 的幂次请求、伙伴合并、超额分配
 * 失败，以及空闲链表与计数一致性等场景。任一断言失败都会终止内核。
 */
static void
buddy_check(void) {
    cprintf("buddy_check: start\n");

    cprintf("Case 1: allocating 1, 2 and 4 pages\n");
    size_t nr_free_store = nr_free_pages();
    struct Page *p1 = alloc_page();
    assert(p1 != NULL);
    assert(page_ref(p1) == 0);
    assert(nr_free_pages() == nr_free_store - 1);

    struct Page *p2 = alloc_pages(2);
    assert(p2 != NULL);
    assert(page_ref(p2) == 0);
    assert(nr_free_pages() == nr_free_store - 3);

    struct Page *p4 = alloc_pages(4);
    assert(p4 != NULL);
    assert(page_ref(p4) == 0);
    assert(nr_free_pages() == nr_free_store - 7);

    free_page(p1);
    assert(nr_free_pages() == nr_free_store - 6);
    free_pages(p2, 2);
    assert(nr_free_pages() == nr_free_store - 4);
    free_pages(p4, 4);
    assert(nr_free_pages() == nr_free_store);
    cprintf("alloc_pages(1/2/4) test passed!\n");

    cprintf("Case 2: allocating 3 pages (rounded up to 4 pages)\n");
    nr_free_store = nr_free_pages();
    struct Page *p3 = alloc_pages(3);
    assert(p3 != NULL);
    assert(page_ref(p3) == 0);
    assert(!PageProperty(p3));
    assert(nr_free_pages() == nr_free_store - 4);
    free_pages(p3, 3);
    assert(nr_free_pages() == nr_free_store);
    cprintf("alloc_pages(3) test passed!\n");

    cprintf("Case 3: checking buddy block merging\n");
    /* 临时摘除部分空闲块，构造出便于观察两个相邻页合并的初始状态。 */
    list_entry_t detached_blocks;
    list_init(&detached_blocks);
    size_t detached_pages[MAX_ORDER] = {0};
    for (size_t order = 0; order < MAX_ORDER; order ++) {
        list_entry_t *le = list_next(&(free_area[order].free_list));
        while (le != &(free_area[order].free_list)) {
            list_entry_t *next = list_next(le);
            struct Page *page = le2page(le, page_link);
            if (order == 0 || (page2ppn(page) & 1U)) {
                list_del(le);
                list_add_before(&detached_blocks, le);
                detached_pages[order] += 1U << order;
            }
            le = next;
        }
    }
    for (size_t order = 0; order < MAX_ORDER; order ++) {
        free_area[order].nr_free -= detached_pages[order];
    }

    nr_free_store = nr_free_pages();
    /* 连续申请两个单页块，它们的页号应相邻且互为伙伴。 */
    struct Page *pa = alloc_page();
    struct Page *pb = alloc_page();
    assert(pa != NULL && pb != NULL);
    assert(pa != pb);
    assert(nr_free_pages() == nr_free_store - 2);
    assert(page2ppn(pb) == page2ppn(pa) + 1);
    assert((page2ppn(pa) ^ 1U) == page2ppn(pb));

    free_page(pa);
    assert(nr_free_pages() == nr_free_store - 1);
    /* 释放第二个块后，两个页应合并为更高阶的单个空闲块。 */
    free_page(pb);
    assert(nr_free_pages() == nr_free_store);

    int merged = 0;
    for (size_t order = 1; order < MAX_ORDER; order ++) {
        list_entry_t *le = &(free_area[order].free_list);
        while ((le = list_next(le)) != &(free_area[order].free_list)) {
            struct Page *page = le2page(le, page_link);
            if (page <= pa && pa < page + (1U << order) &&
                page <= pb && pb < page + (1U << order)) {
                assert(PageProperty(page));
                assert(page->property == order);
                merged = 1;
            }
        }
    }
    assert(merged);

    while (!list_empty(&detached_blocks)) {
        /* 把 Case 3 中临时摘除的块恢复到原阶数链表。 */
        list_entry_t *le = list_next(&detached_blocks);
        list_del(le);
        struct Page *page = le2page(le, page_link);
        size_t order = page->property;
        assert(order < MAX_ORDER);
        add_free_block(page, order);
    }
    cprintf("buddy merge test passed!\n");

    cprintf("Case 4: requesting more pages than available\n");
    /* 请求页数超过当前空闲总量时必须失败，且不能改变空闲页计数。 */
    nr_free_store = nr_free_pages();
    assert(alloc_pages(nr_free_store + 1) == NULL);
    assert(nr_free_pages() == nr_free_store);
    cprintf("oversized allocation test passed!\n");

    size_t total = 0;
    for (size_t order = 0; order < MAX_ORDER; order ++) {
        /* 校验每个链表中的块阶数、地址顺序和 nr_free 统计是否一致。 */
        size_t order_pages = 0;
        struct Page *previous = NULL;
        list_entry_t *le = &(free_area[order].free_list);
        while ((le = list_next(le)) != &(free_area[order].free_list)) {
            struct Page *page = le2page(le, page_link);
            assert(PageProperty(page));
            assert(page->property == order);
            if (previous != NULL) {
                assert(page2pa(previous) < page2pa(page));
            }
            previous = page;
            order_pages += 1U << order;
        }
        assert(order_pages == free_area[order].nr_free);
        total += order_pages;
    }
    assert(total == nr_free_pages());

    cprintf("buddy_check() succeeded!\n");
}

/* 向物理内存管理器注册伙伴系统的各回调函数。 */
const struct pmm_manager buddy_pmm_manager = {
    .name = "buddy_pmm_manager",
    .init = buddy_init,
    .init_memmap = buddy_init_memmap,
    .alloc_pages = buddy_alloc_pages,
    .free_pages = buddy_free_pages,
    .nr_free_pages = buddy_nr_free_pages,
    .check = buddy_check,
};
