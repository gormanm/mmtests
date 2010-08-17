/*
 * This file is directly taken from the kernel. It is to print out the buddyinfo
 * information to a proc buffer. This is important during high-order allocation
 * stress tests as we want to know what the free pages looked like at the time
 * of an allocation failure
 */
#include <linux/version.h>
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,6,33))
#include <linux/autoconf.h>
#else
#include <generated/autoconf.h>
#endif
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,6,19))
#include <linux/config.h>
#endif
#include <linux/fs.h>
#include <linux/types.h>
#include <linux/proc_fs.h>
#include <linux/kernel.h>
#include <linux/module.h>
#include <asm/uaccess.h>

#include <linux/mmzone.h>
#include <vmregress_core.h>
#include <procprint.h>
#include <linux/mm.h>
#include <linux/spinlock.h>
#include <vmr_mmzone.h>

#define MODULENAME "BuddyInfo Core"
/* Module Description */
MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("VM Regress Buddyinfo exporter");
MODULE_LICENSE("GPL");

#ifdef for_each_rclmtype_order
int printp_buddyinfo(vmr_desc_t *testinfo, int procentry,
					int attempt, int success)
{
	struct pglist_data *pgdat;
	struct zone *zone;
	struct zone *node_zones;
	unsigned long flags;
	int order, t;
	int nid;
	struct free_area *area;
	unsigned long nr_free[MAX_ORDER];
	printp("Buddyinfo %s attempt %d at jiffy index %lu\n", 
			success ? "success" : "failed", attempt, jiffies);

	for_each_online_node(nid) {
		pgdat = NODE_DATA(nid);
		node_zones = pgdat->node_zones;
		for (zone = node_zones; zone - node_zones < MAX_NR_ZONES; ++zone) {
			if (!zone->present_pages)
				continue;

			memset(nr_free, 0, sizeof(nr_free));
			spin_lock_irqsave(&zone->lock, flags);
#ifdef BITS_PER_RCLM_TYPE
			for_each_rclmtype_order(t, order) {
				area = &(zone->free_area_lists[order]);
				nr_free[order] += area->nr_free;
			}
#else
			for_each_rclmtype_order(t, order) {
				area = &(zone->free_area[order]);
				nr_free[order] += area->nr_free;
			}
#endif
			spin_unlock_irqrestore(&zone->lock, flags);

			printp("Node %d, zone %8s", pgdat->node_id, zone->name);
			for (order = 0; order < MAX_ORDER; ++order)
				printp("%6lu ", nr_free[order]);
			printp("\n");
		}
	};

	return 0;
}
#else
int printp_buddyinfo(vmr_desc_t *testinfo, int procentry,
						int attempt, int success)
{
	pg_data_t *pgdat;
	struct zone *zone;
	struct zone *node_zones;
	unsigned long flags;
	int order;
	int nid;
	unsigned long nr_free[MAX_ORDER];
	printp("Buddyinfo %s attempt %d at jiffy index %lu\n", 
			success ? "success" : "failed", attempt, jiffies);

	for_each_online_node(nid) {
		pgdat = NODE_DATA(nid);
		node_zones = pgdat->node_zones;
		if (!node_zones)
			continue;
		for (zone = node_zones; zone - node_zones < MAX_NR_ZONES; ++zone) {
			if (!zone)
				continue;

			if (!zone->present_pages)
				continue;

			/*
			 * printp is known to have oopsed, so don't use it with
			 * a spinlock
			 */
			spin_lock_irqsave(&zone->lock, flags);
			for (order = 0; order < MAX_ORDER; ++order)
				nr_free[order] = zone->free_area[order].nr_free;
			spin_unlock_irqrestore(&zone->lock, flags);

			printp("Node %d, zone %8s", pgdat->node_id, zone->name);
			for (order = 0; order < MAX_ORDER; ++order)
				printp("%6lu ", nr_free[order]);
			printp("\n");
		}
	};

	return 0;
}
#endif

EXPORT_SYMBOL(printp_buddyinfo);
