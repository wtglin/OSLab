#include <slub.h>

#include <assert.h>
#include <pmm.h>
#include <stdio.h>

/*
 * 简化版 SLUB（Simple List of Unused Blocks）对象分配器。
 *
 * SLUB 分为两层：下层通过 alloc_pages() 从物理页分配器取得连续页，上层
 * 把这些页切分成固定大小的对象，并用对象自身的内存保存空闲链表指针。
 * 每个 kmem_cache 描述一种对象大小，所有 cache 复用固定的 cache_pool。
 */

/* 对象起始地址按 8 字节对齐，保证指针可以安全地写入对象内部。 */
#define SLUB_ALIGN      8
/* 最多同时容纳的缓存种类数，避免引入动态控制结构。 */
#define SLUB_MAX_CACHES 16

/*
 * A kmem_cache owns one or more slabs.  A slab is a run of contiguous
 * physical pages obtained from the page allocator.  Free objects are linked
 * together through the first word of the object itself, so no extra metadata
 * is needed for the free list.
 */
struct kmem_cache {
    const char *name;
    size_t object_size;   /* requested size, rounded up for alignment */
    size_t objects_per_slab;
    size_t nr_free;       /* objects currently on the free list */
    size_t nr_slabs;
    void *free_list;
    bool in_use;
};

static struct kmem_cache cache_pool[SLUB_MAX_CACHES];

/*
 * 计算一个 slab 可以切分出的对象数量。
 * 这里采用向下取整，末尾不足一个对象的零头保留不用，确保每个对象都完整
 * 位于该 slab 的页范围内。
 */
static size_t
slub_object_count(size_t page_count, size_t object_size) {
    return (page_count * PGSIZE) / object_size;
}

/* 从 cache_pool 中查找一个尚未使用的控制块；全部占用时返回 NULL。 */
static struct kmem_cache *
slub_cache_alloc_control(void) {
    for (size_t i = 0; i < SLUB_MAX_CACHES; i ++) {
        if (!cache_pool[i].in_use) {
            return &cache_pool[i];
        }
    }
    return NULL;
}

/*
 * Turn newly allocated pages into a slab.  All objects are put on the cache
 * free list; kmem_cache_alloc() then pops the first one.
 *
 * 中文说明：将新申请的连续物理页转换为一个 slab。先由页框号计算内核虚拟
 * 地址，再按 object_size 依次切分对象；每个空闲对象的前 sizeof(void *) 字节
 * 用来保存下一个空闲对象的地址，从而无需额外的空闲链表元数据。
 */
static void
slub_init_slab(struct kmem_cache *cachep, struct Page *page, size_t page_count) {
    assert(cachep != NULL);
    assert(page != NULL);
    assert(page_count > 0);

    uintptr_t slab = page2pa(page) + va_pa_offset;
    size_t objects = slub_object_count(page_count, cachep->object_size);

    assert(objects > 0);
    cachep->objects_per_slab = objects;
    cachep->nr_slabs ++;

    for (size_t i = 0; i < objects; i ++) {
        /* 把对象头当作 next 指针，采用头插法构建空闲对象链表。 */
        void *obj = (void *)(slab + i * cachep->object_size);
        *(void **)obj = cachep->free_list;
        cachep->free_list = obj;
        cachep->nr_free ++;
    }
}

/*
 * 创建一种对象大小的缓存。
 * 对象大小先向上对齐到 8 字节，并至少能容纳一个指针，因为空闲对象需要
 * 用自身内存链接下一个空闲对象。新建 cache 初始没有 slab，首次分配时再
 * 向物理页分配器申请页面。
 */
struct kmem_cache *
kmem_cache_create(const char *name, size_t size) {
    assert(name != NULL);
    assert(size > 0);

    size_t object_size = ROUNDUP(size, SLUB_ALIGN);
    if (object_size < sizeof(void *)) {
        object_size = sizeof(void *);
    }

    struct kmem_cache *cachep = slub_cache_alloc_control();
    if (cachep == NULL) {
        return NULL;
    }

    cachep->name = name;
    cachep->object_size = object_size;
    cachep->objects_per_slab = 0;
    cachep->nr_free = 0;
    cachep->nr_slabs = 0;
    cachep->free_list = NULL;
    cachep->in_use = 1;

    cprintf("slub: created cache '%s', object size %d bytes\n", name,
            (int)object_size);
    return cachep;
}

/*
 * 从指定 cache 分配一个对象。
 * 若空闲链表非空，直接弹出链表头；否则先申请足够容纳一个对象的连续页，
 * 把这些页初始化为新 slab，再从新链表中弹出一个对象。
 */
void *
kmem_cache_alloc(struct kmem_cache *cachep) {
    assert(cachep != NULL);
    assert(cachep->in_use);

    if (cachep->free_list == NULL) {
        /*
         * A normal object needs one page.  Larger objects get as many
         * contiguous pages as required, which also keeps the implementation
         * correct for caches whose object size exceeds PGSIZE.
         *
         * 中文说明：普通小对象只需一页；若对象本身大于一页，则向上取整
         * 申请多个连续页，保证 slab 内有空间完整存放至少一个对象。
         */
        size_t page_count = ROUNDUP(cachep->object_size, PGSIZE) / PGSIZE;
        struct Page *page = alloc_pages(page_count);
        if (page == NULL) {
            return NULL;
        }
        slub_init_slab(cachep, page, page_count);
    }

    void *obj = cachep->free_list;
    cachep->free_list = *(void **)obj;
    cachep->nr_free --;
    return obj;
}

/*
 * 将对象归还到 cache 的空闲链表。
 * 这里采用头插法，因此刚释放的对象会优先被下一次分配复用；对象头中
 * 原用户数据会被 next 指针覆盖，这是空闲对象的正常状态。
 */
void
kmem_cache_free(struct kmem_cache *cachep, void *objp) {
    assert(cachep != NULL);
    assert(cachep->in_use);
    assert(objp != NULL);
    assert(((uintptr_t)objp & (SLUB_ALIGN - 1)) == 0);

    *(void **)objp = cachep->free_list;
    cachep->free_list = objp;
    cachep->nr_free ++;
}

/* 在线性数组中查找指针 ptr，用于测试对象是否来自指定分配批次。 */
static bool
slub_ptr_in_array(void *ptr, void **array, size_t count) {
    for (size_t i = 0; i < count; i ++) {
        if (array[i] == ptr) {
            return 1;
        }
    }
    return 0;
}

/* 断言指针满足 SLUB 的 8 字节对齐要求。 */
static void
slub_assert_aligned(void *ptr) {
    assert(((uintptr_t)ptr & (SLUB_ALIGN - 1)) == 0);
}

/* 断言数组中的对象均非空、对齐且互不重叠。 */
static void
slub_assert_distinct(void **array, size_t count) {
    for (size_t i = 0; i < count; i ++) {
        assert(array[i] != NULL);
        slub_assert_aligned(array[i]);
        for (size_t j = 0; j < i; j ++) {
            assert(array[i] != array[j]);
        }
    }
}

/*lab2 challenge-1*/
/*
 * SLUB 自检入口，依次验证基本分配复用、跨页 slab、多 cache 隔离以及
 * 对象地址对齐。测试使用固定 cache 和静态对象数组，最后由 init.c 调用。
 */
void
slub_check(void) {
    cprintf("slub_check: start\n");

    cprintf("slub_check: Case 1 - basic allocation and reuse (32B)\n");
    struct kmem_cache *cache32 = kmem_cache_create("slub-32", 32);
    assert(cache32 != NULL);

    /* Case 1：首次分配的 3 个对象应互不相同且位于同一个 slab 内。 */
    void *basic[3];
    for (size_t i = 0; i < 3; i ++) {
        basic[i] = kmem_cache_alloc(cache32);
    }
    slub_assert_distinct(basic, 3);
    for (size_t i = 0; i < 3; i ++) {
        kmem_cache_free(cache32, basic[i]);
    }

    void *reused[3];
    for (size_t i = 0; i < 3; i ++) {
        /* 全部释放后重新分配，验证空闲对象确实被回收并复用。 */
        reused[i] = kmem_cache_alloc(cache32);
        assert(reused[i] != NULL);
        assert(slub_ptr_in_array(reused[i], basic, 3));
    }
    slub_assert_distinct(reused, 3);
    for (size_t i = 0; i < 3; i ++) {
        kmem_cache_free(cache32, reused[i]);
    }
    cprintf("slub_check: Case 1 passed\n");

    cprintf("slub_check: Case 1b - cross-page allocation (16B, 300 objs)\n");
    struct kmem_cache *cache16 = kmem_cache_create("slub-16", 16);
    assert(cache16 != NULL);

    /* 16B 对象使单页可容纳 256 个对象，申请 300 个必然跨越多个 slab。 */
    static void *many[300];
    for (size_t i = 0; i < 300; i ++) {
        many[i] = kmem_cache_alloc(cache16);
    }
    slub_assert_distinct(many, 300);
    assert(cache16->nr_slabs >= 2);
    for (size_t i = 0; i < 300; i ++) {
        kmem_cache_free(cache16, many[i]);
    }

    static void *many_again[300];
    for (size_t i = 0; i < 300; i ++) {
        many_again[i] = kmem_cache_alloc(cache16);
    }
    slub_assert_distinct(many_again, 300);
    for (size_t i = 0; i < 300; i ++) {
        /* 再次分配得到的对象应全部来自上一轮释放的对象集合。 */
        assert(slub_ptr_in_array(many_again[i], many, 300));
    }
    for (size_t i = 0; i < 300; i ++) {
        kmem_cache_free(cache16, many_again[i]);
    }
    cprintf("slub_check: Case 1b passed\n");

    cprintf("slub_check: Case 2 - mixed cache sizes (32B/64B/256B)\n");
    struct kmem_cache *c32 = kmem_cache_create("slub-mixed-32", 32);
    struct kmem_cache *c64 = kmem_cache_create("slub-mixed-64", 64);
    struct kmem_cache *c256 = kmem_cache_create("slub-mixed-256", 256);
    assert(c32 != NULL && c64 != NULL && c256 != NULL);

    /* 同时使用三种对象大小的 cache，检查不同 cache 的对象地址无交叉。 */
    void *objs32[8], *objs64[8], *objs256[8];
    for (size_t i = 0; i < 8; i ++) {
        objs32[i] = kmem_cache_alloc(c32);
        objs64[i] = kmem_cache_alloc(c64);
        objs256[i] = kmem_cache_alloc(c256);
    }
    slub_assert_distinct(objs32, 8);
    slub_assert_distinct(objs64, 8);
    slub_assert_distinct(objs256, 8);

    for (size_t i = 0; i < 8; i ++) {
        assert(!slub_ptr_in_array(objs32[i], objs64, 8));
        assert(!slub_ptr_in_array(objs32[i], objs256, 8));
        assert(!slub_ptr_in_array(objs64[i], objs256, 8));
    }

    for (size_t i = 0; i < 8; i ++) {
        /* 每种 cache 独立维护空闲链表，释放后应立即复用刚释放的对象。 */
        kmem_cache_free(c32, objs32[i]);
        kmem_cache_free(c64, objs64[i]);
        kmem_cache_free(c256, objs256[i]);

        void *n32 = kmem_cache_alloc(c32);
        void *n64 = kmem_cache_alloc(c64);
        void *n256 = kmem_cache_alloc(c256);

        assert(n32 == objs32[i]);
        assert(n64 == objs64[i]);
        assert(n256 == objs256[i]);
        slub_assert_aligned(n32);
        slub_assert_aligned(n64);
        slub_assert_aligned(n256);

        kmem_cache_free(c32, n32);
        kmem_cache_free(c64, n64);
        kmem_cache_free(c256, n256);
    }
    cprintf("slub_check: Case 2 passed\n");

    cprintf("slub_check: Case 3 - 8-byte alignment\n");
    /* Case 3：所有返回给用户的对象地址都必须满足 8 字节对齐。 */
    void *aligned = kmem_cache_alloc(c32);
    assert(aligned != NULL);
    assert(((uintptr_t)aligned & (SLUB_ALIGN - 1)) == 0);
    cprintf("slub_check: pointer %p is 8-byte aligned\n", aligned);
    kmem_cache_free(c32, aligned);
    cprintf("slub_check: Case 3 passed\n");

    cprintf("slub_check() succeeded!\n");
}
