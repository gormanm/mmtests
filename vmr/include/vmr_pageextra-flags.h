#ifndef __VMR_PAGEEXTRA_FLAGS_H
#define __VMR_PAGEEXTRA_FLAGS_H

#include <linux/mmzone.h>

#ifndef PAGEEXTRA_FLAGS_H
enum pageextra_bits {
	PE_type,
	PE_unmovable,
	PE_reclaimable,
	PE_movable,
	PE_highatomic,
	PE_type_end,
	NR_PAGEEXTRA_BITS
};

#ifndef MIGRATE_UNMOVABLE
#define MIGRATE_UNMOVABLE     0
#define MIGRATE_RECLAIMABLE   1
#define MIGRATE_MOVABLE       2
#define MIGRATE_RESERVE       3
#define MIGRATE_TYPES         4

#define GFP_MOVABLE_MASK (__GFP_RECLAIMABLE|__GFP_MOVABLE)

/* Convert GFP flags to their corresponding migrate type */
static inline int allocflags_to_migratetype(gfp_t gfp_flags)
{
	/* Group based on mobility */
	return (((gfp_flags & __GFP_MOVABLE) != 0) << 1) |
		((gfp_flags & __GFP_RECLAIMABLE) != 0);
}

#endif /* MIGRATE_MOVABLE */

#ifdef CONFIG_PAGE_OWNER
int page_group_by_mobility_disabled;
#endif

/* If patch is not applied, fudge as best as possible */
static inline int get_pageextra_type(struct page *page) {
#ifdef CONFIG_PAGE_OWNER
	int migratetype = allocflags_to_migratetype(page->gfp_mask);
	switch(migratetype) {
		case MIGRATE_UNMOVABLE:
			return PE_unmovable;
		case MIGRATE_RECLAIMABLE:
			return PE_reclaimable;
		case MIGRATE_MOVABLE:
			return PE_movable;
	}
	printk("Unknown type %d\n", migratetype);
	return PE_unmovable;
#else
	if (PageLRU(page))
		return PE_movable;
	
	return PE_unmovable;
#endif /* PAGE_OWNER */
}
#endif /* PAGEEXTRA_FLAGS_H */

#endif /* __VMR_PAGEEXTRA_FLAGS_H */
