/*
 * vmr_mmzone.h
 *
 * This is something I fairly hate having to do. The names of structs has
 * changed between Kernel 2.4 and 2.5.x meaning that there is two choices,
 * fork and maintain two separate VM Regress trees or work around with
 * #define-s, helper macros or whatnot. Forking is probably the "right" 
 * solution but the workarounds allow the body of work to remain in one
 * tree and having VM Regress work between kernel versions is desirable so...
 * you guessed it, workarounds it is!
 * conflicting names.
 */
#ifndef __VMR_MMZONE_H_
#define __VMR_MMZONE_H_

#include <linux/module.h>
#include <linux/version.h>

/*
 * How pgdats were steped through in 2.4 and late 2.5 is different because 
 * node_next was changed to pgdat_next. To avoid having #defines in the code,
 * this header file hides the difference
 */

#ifndef _LINUX_MMZONE_H
#error linux/mmzone.h has to be be included before vmr_mmzone.h
#endif

/*
 * The kernel version is used to determine how to step to the next pgdat. In
 * 2.5.29, it was changed from node_next to pgdat_next
 */

#ifndef KERNEL_VERSION
#define KERNEL_VERSION(a,b,c) (((a) << 16) + ((b) << 8) + (c))
#endif

#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,5,29))

/* Here are 2.4 - 2.5.29 defines */
#define vmr_next_pgdat(pgdat) pgdat = pgdat->node_next
#define vmr_zone_size(zone) zone->size
#define vmr_zone_spanned(zone) 0
#define C_ZONE zone_t
#define C_FREE_AREA struct free_area_struct
#define C_SLAB struct slab_s
#define NODE_SIZE(x) x->node_size

#else

/* Here is all the later 2.5 defines */
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,6,17))
#define vmr_next_pgdat(pgdat) pgdat = pgdat->pgdat_next
#else

struct pglist_data *vmr_next_online_pgdat(struct pglist_data *pgdat) {
	int nid = next_online_node(pgdat->node_id);
	if (nid == MAX_NUMNODES)
		return NULL;
	return NODE_DATA(nid);
}

#define vmr_next_pgdat(pgdat) vmr_next_online_pgdat(pgdat)
#endif
#define vmr_zone_size(zone) zone->present_pages
#define vmr_zone_spanned(zone) zone->spanned_pages
#define C_ZONE struct zone
#define C_FREE_AREA struct free_area
#define C_SLAB struct slab
#define NODE_SIZE(x) x->node_present_pages
#endif

#endif

/* Hack for pgdat walking. for_each_pgdat was removed in 2.6.17 */
#if defined(for_each_pgdat) &&defined(for_each_online_pgdat)
#error BANG
#endif
#ifndef for_each_pgdat
#define for_each_pgdat(pgdat) for_each_online_pgdat(pgdat)
#endif
