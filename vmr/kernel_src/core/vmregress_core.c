/*
 * This is the code of the vmregress set of modules. This provides core 
 * functions that everyone needs and sets up the initial /proc/vmregress
 * entry. It has no real work itself but the functions it provides are
 * listed here
 *
 * o Creation of the /proc/vmregress entry
 * o alloc/free functions for proc buffer space
 * o getting a handle to pgdat_list
 * o provide simple strtol functions
 * o handle scheduling when necessary
 *
 * (c) Mel Gorman 2002
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
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/fs.h>
#include <linux/types.h>
#include <linux/proc_fs.h>
#include <linux/vmalloc.h>
#include <linux/mm.h>
#include <linux/ctype.h>
#include <linux/compiler.h>
#include <linux/sched.h>
#include <linux/interrupt.h>
#include <asm/pgtable.h>

#define MODULENAME "vmr_core"
#include <vmregress_core.h>
#include <vmr_mmzone.h>
#include <procprint.h>
#include <internal.h>

/* Module Description */
MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("VM Regress Core");
MODULE_LICENSE("GPL");

#define PROCBUF_FLAGS (GFP_KERNEL|__GFP_RECLAIMABLE|__GFP_KERNRCLM|__GFP_NOWARN)

/* vmregress proc directory structure */
struct proc_dir_entry *vmregress_proc_dir;

/* Test descriptors, nothing much here as we only create a directory */
#define NUM_PROC_ENTRIES 1
static vmr_desc_t testinfo[] = { VMR_DESC_INIT(0, "vmregress", 0, 0) };

/** 
 * vmrproc_freebuffer - Frees the buffer used for printing proc information
 * @desc: The test descriptor
 *
 * This function will adjust the callers buffer and buffer size parameters. This
 * is handy if the size of the proc buffer is expected to change for the 
 * lifetime of the module
 */
void vmrproc_freebuffer(vmr_desc_t *desc)
{
	if (desc->procbuf) {
		memset(desc->procbuf, 0, desc->procbuf_size);

		if (desc->order == -1)
			vfree(desc->procbuf);
		else
			free_pages((unsigned long)desc->procbuf, desc->order);
	}
	desc->procbuf = NULL;
	desc->order = -1;
	desc->procbuf_size = 0;
}

/**
 * vmrproc_allocbuffer - Allocates a buffer for printing out proc information 
 * @pages - number of pages to allocate
 * @desc - The test descriptor
 */
int vmrproc_allocbuffer(unsigned int pages, vmr_desc_t *desc)
{       
	unsigned int bytes;
	char *oldbuf;
	int attempt = 0;
	int oldorder;

	/* Return if 0 pages were asked for */
	if (!pages) {
		vmr_printk("0 pages requested for proc buffer\n");
		return 0;
	}

	/* Make sure too many pages aren't allocated */
	if (pages > (1 << (MAX_ORDER-1)))
	{
		vmr_printk("Too large a proc buffer of %u pages requested, truncating\n", pages);
		pages = 1 << (MAX_ORDER-1);
		return -ENOMEM;
	}

	/* Allocate buffer */
	bytes = pages * PAGE_SIZE;
	oldbuf = desc->procbuf;
	oldorder = desc->order;
	desc->procbuf = NULL;
	while (desc->procbuf == NULL && attempt++ < 10) {
		int order = fls(pages);
		if (((1 << order)*PAGE_SIZE) < bytes) {
			vmr_printk("BUG: Calculating order (%d) for size (%d)wrong\n", order, bytes);
			break;
		}

		desc->procbuf = (char *)__get_free_pages(PROCBUF_FLAGS, order);
		if (desc->procbuf) {
			desc->order = order;
			vmr_printk("Proc buffer allocated for %d bytes with alloc_pages(flags, %d)\n", bytes, order);
		}
	}

	/* Fallback to vmalloc if necessary */
	if (desc->procbuf == NULL) {
		vmr_printk("Proc buffer allocated for %d bytes with vmalloc(flags, %d)\n", bytes, bytes);
		desc->procbuf = __vmalloc(bytes, PROCBUF_FLAGS|__GFP_HIGHMEM, PAGE_KERNEL);
		desc->order = -1;
	}

	if (!desc->procbuf) {
		vmr_printk("Failed to allocate proc buffer\n");
		desc->procbuf=oldbuf;
		return -ENOMEM;
	}

	/* Init desc */
	desc->written = 0;
	desc->procbuf_size = bytes;
	memset(desc->procbuf, 0, desc->procbuf_size);

	/* 
	 * Delete the old buf if it exists. Intuitively you would expect
	 * the caller to delete the old buffer but this had to be special
	 * cased. UML kept behaving *really* odd if the same area was 
	 * used. This incredibly messy method forces a different vm region
	 * to be used.
	 */
	if (oldbuf) {
		if (oldorder == -1)
			vfree(oldbuf);
		else
			free_pages((unsigned long)oldbuf, oldorder);
	}

	return 0;
}

/**
 * vmrproc_growbuffer - Grow the proc buffer by a number of pages
 * @pages: The number of pages to grow by
 * @desc: The test descriptor struct 
 *
 * This function will grow a buffer of a number of pages and copy in the
 * old contents. It is an expensive function so only use if you have to
 */
int  vmrproc_growbuffer(unsigned int pages, vmr_desc_t *desc) {
	int bytes;	/* Number of bytes in the buffer */
	int oldpages;	/* Number of pages in the old buffer */
	int newpages;   /* Number of pages in the new buffer */
	char *newbuf;	/* The new buffer */
	int attempt=0;
	int order = -1;

	/* Check test flags */
	if (desc->flags & VMR_NOGROW) return 0;

	/* Return if 0 pages were asked for */
	if (!pages) return 0;

	/* Calculate how many pages in the old buffer */
	oldpages = PAGE_ALIGN(desc->procbuf_size) / PAGE_SIZE;
	newpages = oldpages + pages;
	bytes = newpages * PAGE_SIZE;
	newbuf = NULL;

	/* Make sure too many pages aren't allocated */
	if (newpages > 1 << (MAX_ORDER-1))
	{
		vmr_printk("Too large a proc buffer requested, using only vmalloc\n");
		goto vmalloc;
	}

	/* Allocate buffer */
	vmr_printk("Growing proc buffer. Consider increasing page count for vmrproc_alloc\n");

	while (newbuf == NULL && attempt++ < 10) {
		order = fls(newpages);
		if (((1 << order)*PAGE_SIZE) < bytes) {
			vmr_printk("BUG: Calculating order (%d) for size (%d)wrong\n", order, bytes);
			break;
		}

		newbuf = (char *)__get_free_pages(PROCBUF_FLAGS, order);
		if (newbuf) {
			vmr_printk("Proc buffer allocated for %d bytes with alloc_pages(flags, %d)\n", bytes, order);
		}
	}

	/* Fallback to vmalloc if necessary */
vmalloc:
	if (newbuf == NULL) {
		vmr_printk("Proc buffer allocated for %d bytes with vmalloc(flags, %d)\n", bytes, bytes);
		newbuf = __vmalloc(bytes, PROCBUF_FLAGS|__GFP_HIGHMEM, PAGE_KERNEL);
		order = -1;
	}

	if (!newbuf) {
		vmr_printk("Failed to grow proc buffer\n");
		return -ENOMEM;
	}

	/* Copy in the old buffer data */
	memcpy(newbuf, desc->procbuf, oldpages * PAGE_SIZE);

	/* Delete the old buffer and replace it*/
	vmrproc_freebuffer(desc);
	desc->procbuf = newbuf;
	desc->procbuf_size = bytes;
	desc->order = order;

	/* Return success */
	return 0;
}


#ifndef PGDAT_LIST_EXPORTED
	struct page pgdat_page;
	struct address_space swapper_space;
	pg_data_t *pgdat_list;

	/* This could be dangerous :-( */
	EXPORT_SYMBOL(swapper_space);
	EXPORT_SYMBOL(pgdat_list);
#endif

/**
 *
 * get_pgdat_list - Return the pgdat_list
 * @page - A page provided to track the parent pgdat_list if necessary
 *
 * This is the first link in the nodes belonging to the system. Normally to 
 * access it, the pgdat_list must be exported but if it is not exported, a 
 * workaround is provided here which will use a page to get the zone giving 
 * it's pgdat. There is no guarentee that we'll get the first pgdat but on 
 * machines with just one node like the x86, it is not important. For NUMA 
 * machines, the kernel must be patched to export the symbol
 *
 */
#ifndef PGDAT_LIST_EXPORTED
int warned_pgdat=0;
#endif
pg_data_t *get_pgdat_list(void) {
	struct page *page;

#ifdef PGDAT_LIST_EXPORTED
	return pgdat_list;
#else
	C_ZONE  *zone;

	if (!warned_pgdat) {
		vmr_printk("Warning - No guarentee all memory nodes are visible. Kernel patch required\n");
		warned_pgdat = 1;
	}

	page = alloc_pages_node(0, GFP_KERNEL, 0);
	if (!page) {
		if (!warned_pgdat) {
			vmr_printk("get_pgdat_list() failued. Could not get page from node 0\n");
			warned_pgdat = 1;
		}
		return NULL;
	}

	zone = page_zone(page);
	if (!zone) {
		if (!warned_pgdat) {
			vmr_printk("get_pgdat_list() failued. Could not zone for zero page\n");
			warned_pgdat = 1;
		}
		return NULL;
	}

	__free_pages(page, 0);
	return zone->zone_pgdat;
#endif
}

/* Taken directly from the Linux Kernel Source lib/vsprinf.c */

/**
 * vmr_strtoul - convert a string to an unsigned long
 * @cp: The start of the string
 * @endp: A pointer to the end of the parsed string will be placed here
 * @base: The number base to use
 */
unsigned long vmr_strtoul(const char *cp,char **endp,unsigned int base)
{
	unsigned long result = 0,value;

	if (!base) {
		base = 10;
		if (*cp == '0') {
			base = 8;
			cp++;
			if ((*cp == 'x') && isxdigit(cp[1])) {
				cp++;
				base = 16;
			}
		}
	}
	while (isxdigit(*cp) &&
	       (value = isdigit(*cp) ? *cp-'0' : toupper(*cp)-'A'+10) < base) {
		result = result*base + value;
		cp++;
	}
	if (endp)
		*endp = (char *)cp;
	return result;
}

/**
 * vmr_strtol - convert a string to a signed long
 * @cp: The start of the string
 * @endp: A pointer to the end of the parsed string will be placed here
 * @base: The number base to use
 */
long vmr_strtol(const char *cp,char **endp,unsigned int base)
{
	if(*cp=='-')
		return -vmr_strtoul(cp+1,endp,base);
	return vmr_strtoul(cp,endp,base);
}

/**
 * check_resched_nocount - Checks if schedule needs to be called
 *
 * Return Value 
 * 0 If schedule was not called
 * 1 If schedule was called
 */
int check_resched_nocount(void) {
	if (in_interrupt() || !current) return 0;

#ifdef HAVE_NEED_RESCHED
	if (need_resched()) {
#else
	if (unlikely(current->need_resched)) {
#endif
		__set_current_state(TASK_RUNNING);
		schedule();
		return 1;
	}

	return 0;
}

	
/* Export function symbols to other modules */
EXPORT_SYMBOL(vmregress_proc_dir);
EXPORT_SYMBOL(vmrproc_freebuffer);
EXPORT_SYMBOL(vmrproc_allocbuffer);
EXPORT_SYMBOL(vmrproc_growbuffer);
EXPORT_SYMBOL(get_pgdat_list);
EXPORT_SYMBOL(vmr_strtoul);
EXPORT_SYMBOL(vmr_strtol);
EXPORT_SYMBOL(check_resched_nocount);

/* Module init */
#define VMR_MODULE_HAS_NO_FILE_ENTRIES
#include "../init/init.c"
