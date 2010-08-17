#ifndef __VMREGRESS_CORE_H
#define __VMREGRESS_CORE_H

/* Includes needed everywhere */
#if (LINUX_VERSION_CODE > KERNEL_VERSION(2,6,19))
#include <linux/jiffies.h>
#include <linux/sched.h>
#endif

/* vmregress proc directory structure */
extern struct proc_dir_entry *vmregress_proc_dir;

/* ----- Time related macros ----- */

/* Check resched and wrapper macro */
int check_resched_nocount(void);
#define check_resched(counter) if (check_resched_nocount() == 1) counter++

/* This converts a jiffy value to milliseconds */
#define jiffies_to_ms(start) ((1000 * (jiffies - start)) / HZ)

/* Acquire pgdat_list */
pg_data_t *get_pgdat_list(void);

/* String to long converters */
unsigned long vmr_strtoul(const char *cp,char **endp,unsigned int base);
long vmr_strtol(const char *cp,char **endp,unsigned int base);

/* 
 * ----- VMR description structure -----
 *
 * Each module could have a number of different tests and proc entries.
 * This structure keeps information in a single place. To use the printp
 * macro, this structure should be called testinfo
 */
typedef struct vmr_desc {
	/* Lock to data */
	spinlock_t lock;	/* Lock to protect struct. Mainly
				 * of importance to setting the
				 * pid of who is writing. Many
				 * tests can run but only one
				 * PID may write to the buffer
				 */

	/* Proc entry info */
	int procentry;		/* Index of proc buffer been written to */
	char *procbuf;		/* Buffer to print to */
	int order;		/* -1 if vmalloc. size of buf if alloc_pages */
	int procbuf_size; 	/* Buffer size */
	int written;		/* Bytes written to buffer */
	pid_t pid;		/* PID of the test writer */

	/* Persistent info */
	unsigned long mapaddr;	/*
				 * Address of a memory mapped
				 * area. This is needed for
				 * printing out pages present
				 * or swapped within a region.
				 * See pagetable.c:vmr_printpage
				 */

	/* Test configuration */
	char name[40];		/* Name of the test */
	unsigned long flags;	/* Bitmap of test flags */

	/* Read/Write procedures for this proc entry */
	int (*read_proc)(char *buf, char **start, off_t offset, int count, int *eof,void *data);
	int (*write_proc)(struct file *file, const char *buf, unsigned long count, void *data);
	

} vmr_desc_t;
 
/* Small macro to init a struct statically */
#define VMR_DESC_INIT(a, b, c, d ) {SPIN_LOCK_UNLOCKED, a, 0, 0, -1, 0, 0, 0, b, 0, c, d }

/* 
 * Test flags 
 *
 * Each test can have a number of flags. This is a full list of what bits
 * can be set
 *
 * VMR_PRINTMAP - If set, a map of the process address space will be printed 
 *                out in an encoded format where appropriate. This can be 
 *                used to determine what pages are present and what is 
 *                swapped out
 *
 * VMR_PRINTMANY - If set, multiple tests are allowed to print to the proc
 *                buffer. The way to distinguish them is that the PID of
 *                the test will be prepended to every line. A simple grep
 *                will produce the individual results
 *
 * VMR_NOGROW -   If set printp and vmr_snprintf will not grow the proc
 *                buffer size
 *
 * VMR_WAITPROC - If this flag is set, a caller will block waiting for a
 * 		  proc buffer to be free. This is important when the 
 * 		  caller must see their own output and are willing to
 * 		  wait for it
 *
 */

#define VMR_PRINTMAP 	0x00000001
#define VMR_PRINTMANY	0x00000002
#define VMR_NOGROW	0x00000004
#define VMR_WAITPROC 	0x00000008

/* GFP Flags */
#ifndef __GFP_EASYRCLM
#define __GFP_EASYRCLM 0
#define FAKED_GFP_EASYRCLM
#endif /* __GFP_EASYRCLM */
#ifndef __GFP_MOVABLE
#define __GFP_MOVABLE 0
#define FAKED_GFP_MOVABLE
#endif /* __GFP_MOVABLE */
#ifndef __GFP_RECLAIMABLE
#define __GFP_RECLAIMABLE 0
#endif
#ifndef __GFP_KERNRCLM
#define __GFP_KERNRCLM 0
#endif

/* Slab */
#ifndef DEBUG
#define DEBUG 0
#endif
#ifndef STATS
#define STATS 0
#endif /* STATS */

/* zone->free_pages */
#if (LINUX_VERSION_CODE > KERNEL_VERSION(2,6,19))
//#define zone_free_pages(zone) zone_page_state(zone, NR_FREE_PAGES)
#define zone_free_pages(zone) 0UL
#else
#define zone_free_pages(zone) zone->free_pages
#endif

/* zone watermarks */
#if (LINUX_VERSION_CODE < KERNEL_VERSION(2,6,30))
#define min_wmark_pages(z) z->pages_min
#define low_wmark_pages(z) z->pages_low
#define high_wmark_pages(z) z->pages_high
#endif

#endif
