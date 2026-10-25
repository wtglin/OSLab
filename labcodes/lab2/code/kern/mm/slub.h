#ifndef __KERN_MM_SLUB_H__
#define __KERN_MM_SLUB_H__

#include <defs.h>

struct kmem_cache;

struct kmem_cache *kmem_cache_create(const char *name, size_t size);
void *kmem_cache_alloc(struct kmem_cache *cachep);
void kmem_cache_free(struct kmem_cache *cachep, void *objp);
void slub_check(void);

#endif /* !__KERN_MM_SLUB_H__ */
