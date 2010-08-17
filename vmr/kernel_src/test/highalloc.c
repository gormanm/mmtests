/*
 * highalloc - Test the allocation of high-order pages
 *
 * Mel Gorman 2005
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

/* Module specific */
#include <vmregress_core.h>
#include <procprint.h>
#include <nanotime.h>
#include <linux/mmzone.h>
#include <linux/mm.h>
#include <linux/vmalloc.h>
#include <linux/spinlock.h>
#include <linux/highmem.h>
#include <asm/rmap.h>		/* Included only if available */
#include <vmr_mmzone.h>

#define MODULENAME "test_highalloc"
#define NUM_PROC_ENTRIES 3

#define HIGHALLOC_REPORT 0
#define HIGHALLOC_TIMING  1
#define HIGHALLOC_BUDDYINFO  2

static vmr_desc_t testinfo[] = {
	VMR_DESC_INIT(HIGHALLOC_REPORT, MODULENAME , vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(HIGHALLOC_TIMING, MODULENAME "_timings", vmr_read_proc, vmr_write_proc),
	VMR_DESC_INIT(HIGHALLOC_BUDDYINFO, MODULENAME "_buddyinfo", vmr_read_proc, vmr_write_proc),
};

MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Test high order allocations");
MODULE_LICENSE("GPL");

/* Boolean to indicate whether to use gfp_highuser or not */
int gfp_highuser;
int ms_delay=100;
int expected_count=1;

/*
 * 256 == Attempt line
 * num_online_nodes == what you expect
 * 30 == Node x, zone y string
 * 15 * MAX_ORDER == buddyinfo information
 */
#define PROCBUF_INIT_PAGES ((PAGE_SIZE + expected_count * ((256 + 30 + 15 * MAX_ORDER) * num_online_nodes())) / PAGE_SIZE)

#ifdef MODULE_PARM
MODULE_PARM(gfp_highuser, "i");
MODULE_PARM(ms_delay, "i");
MODULE_PARM(expected_count, "i");
#else
module_param(gfp_highuser, int, 0);
module_param(ms_delay, int, 0);
module_param(expected_count, int, 0);
#endif

MODULE_PARM_DESC(gfp_highuser, "Set to 1 if gfp_highuser is to be used with alloc_pages");
MODULE_PARM_DESC(ms_delay, "The number of milliseconds to delay between allocation attempts. Defaults to 100");
MODULE_PARM_DESC(expected_count, "The expected number of pages that will be requested. Defaults to 1");


/* GFP flags to use with __alloc_pages. defaults to GFP_USER */
unsigned int gfp_flags=GFP_USER;

/**
 * test_alloc_help - Print help message to proc buffer
 * @procentry: Which proc buffer to write to
 */
void test_alloc_help(int procentry) {
	vmrproc_openbuffer(&testinfo[procentry]);

	printp("%s%s\n\n", MODULENAME, testinfo[procentry].name);
	printp("To run test, run \n");
	printp("echo order number > /proc/vmregress/%s\n\n", MODULENAME);
	printp("gfp_highuser = %d\n", gfp_highuser);
	printp("ms_delay = %d\n", ms_delay);
	printp("expected_count = %d\n", expected_count);
	printp("procbuf starting pages = %lu\n", PROCBUF_INIT_PAGES);
	
	vmrproc_closebuffer(&testinfo[procentry]);
}

/**
 *
 * test_alloc_runtest - Allocate and free a number of pages from a ZONE_NORMAL
 * @params: Parameters read from the proc entry
 * @argc:   Number of parameters actually entered
 * @procentry: Proc buffer to write to
 *
 * If pages is set to 0, pages will be allocated until the pages_high watermark
 * is hit
 * Returns
 * 0  on success
 * -1 on failure
 *
 */
int test_alloc_runtest(int *params, int argc, int procentry) {
	unsigned long order;		/* Order of pages */
	unsigned long numpages;		/* Number of pages to allocate */
	struct page **pages;		/* Pages that were allocated */
	unsigned long attempts=0;
	unsigned long alloced=0;
	unsigned long nextjiffies = jiffies;
	unsigned long lastjiffies = jiffies;
	unsigned long success=0;
	unsigned long fail=0;
	unsigned long resched_count=0;
	unsigned long aborted=0;
	unsigned long long start_cycles, cycles;
	unsigned long page_dma=0, page_dma32=0, page_normal=0, page_highmem=0, page_easyrclm=0;
	struct zone *zone;
	char finishString[60];
	int timing_pages, pages_required;

	/* Set gfp_flags based on the module parameter */
	if (gfp_highuser) {
#ifdef GFP_RCLMUSER
		vmr_printk("Using highmem with GFP_RCLMUSER\n");
		gfp_flags = GFP_RCLMUSER;
#elif defined(GFP_HIGH_MOVABLE)
		vmr_printk("Using highmem with GFP_HIGH_MOVABLE\n");
		gfp_flags = GFP_HIGH_MOVABLE;
#elif defined(GFP_HIGHUSER_MOVABLE)
		vmr_printk("Using highmem with GFP_HIGHUSER_MOVABLE\n");
		gfp_flags = GFP_HIGHUSER_MOVABLE;
#else
		vmr_printk("Using highmem with GFP_HIGHUSER | __GFP_EASYRCLM\n");
		gfp_flags = GFP_HIGHUSER | __GFP_EASYRCLM;
#endif
	} else {
		vmr_printk("Using lowmem\n");
		gfp_flags |= __GFP_EASYRCLM|__GFP_MOVABLE;
	}
	vmr_printk("__GFP_EASYRCLM is 0x%8X\n", __GFP_EASYRCLM);
	vmr_printk("__GFP_MOVABLE  is 0x%8X\n", __GFP_MOVABLE);
	vmr_printk("gfp_flags       = 0x%8X\n", gfp_flags);
	
	/* Get the parameters */
	order = params[0];
	numpages = params[1];

	/* Make sure a buffer is available */
	if (vmrproc_checkbuffer(testinfo[HIGHALLOC_REPORT])) BUG();
	if (vmrproc_checkbuffer(testinfo[HIGHALLOC_TIMING])) BUG();
	if (vmrproc_checkbuffer(testinfo[HIGHALLOC_BUDDYINFO])) BUG();
	vmrproc_openbuffer(&testinfo[HIGHALLOC_REPORT]);
	vmrproc_openbuffer(&testinfo[HIGHALLOC_TIMING]);
	vmrproc_openbuffer(&testinfo[HIGHALLOC_BUDDYINFO]);

	/* Check parameters */
	if (order < 0 || order >= MAX_ORDER) {
		vmr_printk("Order request of %lu makes no sense\n", order);
		return -1;
	}

	if (numpages < 0) {
		vmr_printk("Number of pages %lu makes no sense\n", numpages);
		return -1;
	}

	/* 
	 * Allocate memory to store pointers to pages.
	 */
	pages = __vmalloc((numpages+1) * sizeof(struct page **),
			GFP_KERNEL|__GFP_HIGHMEM|__GFP_KERNRCLM|__GFP_RECLAIMABLE,
			PAGE_KERNEL);
	if (pages == NULL) {
		printp("Failed to allocate space to store page pointers\n");
		vmrproc_closebuffer(&testinfo[HIGHALLOC_REPORT]);
		vmrproc_closebuffer(&testinfo[HIGHALLOC_TIMING]);
		vmrproc_closebuffer(&testinfo[HIGHALLOC_BUDDYINFO]);
		return 0;
	}

	/* Setup proc buffer for timings */
	timing_pages = testinfo[HIGHALLOC_TIMING].procbuf_size / PAGE_SIZE;
	pages_required = (numpages * 20) / PAGE_SIZE;
	if (pages_required > timing_pages) {
		vmrproc_growbuffer(pages_required - timing_pages, 
					&testinfo[HIGHALLOC_TIMING]);
	}

	/* Setup proc buffer for highorder alloc */
	timing_pages = testinfo[HIGHALLOC_BUDDYINFO].procbuf_size / PAGE_SIZE;
	pages_required = (numpages * ((256 + 30 + 15 * MAX_ORDER) * num_online_nodes())) / PAGE_SIZE;
	if (pages_required > timing_pages) {
		vmrproc_growbuffer(pages_required - timing_pages, 
					&testinfo[HIGHALLOC_BUDDYINFO]);
	}

#if defined(OOM_DISABLE) && (LINUX_VERSION_CODE > KERNEL_VERSION(2,6,19))
	/* Disable OOM Killer */
	vmr_printk("Disabling OOM killer for running process\n");
	oomkilladj = current->oomkilladj;
	current->oomkilladj = OOM_DISABLE;
#endif /* OOM_DISABLE */

	/*
	 * Attempt to allocate the requested number of pages
	 */
	while (attempts++ != numpages) {
		struct page *page;
		if (lastjiffies > jiffies) nextjiffies = jiffies;
		while (jiffies < nextjiffies) check_resched(resched_count);
		nextjiffies = jiffies + ( (HZ * ms_delay)/1000);

		/* Print message if this is taking a long time */
		if (jiffies - lastjiffies > HZ) {
			printk("High order alloc test attempts: %lu (%lu)\n",
					attempts-1, alloced);
		}

		/* Print out a message every so often anyway */
		if (attempts > 1 && (attempts-1) % 10 == 0) {
			printp_entry(HIGHALLOC_TIMING, "\n");
			printk("High order alloc test attempts: %lu (%lu)\n",
					attempts-1, alloced);
		}

		lastjiffies = jiffies;

		start_cycles = read_clockcycles();
		page = alloc_pages(gfp_flags | __GFP_NOWARN, order);
		cycles = read_clockcycles() - start_cycles;

		if (page) {
			printp_entry(HIGHALLOC_TIMING, "%-11llu ", cycles);
			printp_buddyinfo(testinfo, HIGHALLOC_BUDDYINFO, attempts, 1);
			success++;
			pages[alloced++] = page;

			/* Count what zone this is */
			zone = page_zone(page);
			if (zone->name != NULL && !strcmp(zone->name, "EasyRclm")) page_easyrclm++;
			if (zone->name != NULL && !strcmp(zone->name, "Movable")) page_easyrclm++;
			if (zone->name != NULL && !strcmp(zone->name, "HighMem")) page_highmem++;
			if (zone->name != NULL && !strcmp(zone->name, "Normal")) page_normal++;
			if (zone->name != NULL && !strcmp(zone->name, "DMA32")) page_dma32++;
			if (zone->name != NULL && !strcmp(zone->name, "DMA")) page_dma++;


			/* Give up if it takes more than 60 seconds to allocate */
			if (jiffies - lastjiffies > HZ * 600) {
				printk("Took more than 600 seconds to allocate a block, giving up");
				aborted = attempts;
				attempts = numpages;
				break;
			}

		} else {
			printp_entry(HIGHALLOC_TIMING, "-%-10llu ", cycles);
			printp_buddyinfo(testinfo, HIGHALLOC_BUDDYINFO, attempts, 0);
			fail++;

			/* Give up if it takes more than 30 seconds to fail */
			if (jiffies - lastjiffies > HZ * 1200) {
				printk("Took more than 1200 seconds and still failed to allocate, giving up");
				aborted = attempts;
				attempts = numpages;
				break;
			}
		}
	}

	/* Re-enable OOM Killer state */
#ifdef OOM_DISABLED
	vmr_printk("Re-enabling OOM Killer status\n");
	current->oomkilladj = oomkilladj;
#endif

	vmr_printk("Test completed with %lu allocs, printing results\n", alloced);

	/* Print header */
	printp("Order:                 %lu\n", order);
	printp("Allocation type:       %s\n", gfp_highuser ? "HighMem" : "Normal");
	printp("Attempted allocations: %lu\n", numpages);
	printp("Success allocs:        %lu\n", success);
	printp("Failed allocs:         %lu\n", fail);
	printp("DMA32 zone allocs:       %lu\n", page_dma32);
	printp("DMA zone allocs:       %lu\n", page_dma);
	printp("Normal zone allocs:    %lu\n", page_normal);
	printp("HighMem zone allocs:   %lu\n", page_highmem);
	printp("EasyRclm zone allocs:  %lu\n", page_easyrclm);
	printp("%% Success:            %lu\n", (success * 100) / (unsigned long)numpages);

	/*
	 * Free up the pages
	 */
	vmr_printk("Test complete, freeing %lu pages\n", alloced);
	if (alloced > 0) {
		do {
			alloced--;
			if (pages[alloced] != NULL)
				__free_pages(pages[alloced], order);
		} while (alloced != 0);
		vfree(pages);
	}
	
	if (aborted == 0)
		strcpy(finishString, "Test completed successfully\n");
	else
		sprintf(finishString, "Test aborted after %lu allocations due to delays\n", aborted);
	
	printp(finishString);
	vmr_printk("Test completed, closing buffer\n");

	vmrproc_closebuffer(&testinfo[HIGHALLOC_REPORT]);
	vmrproc_closebuffer(&testinfo[HIGHALLOC_TIMING]);
	vmrproc_closebuffer(&testinfo[HIGHALLOC_BUDDYINFO]);
	vmr_printk("%s", finishString);
	return 0;
}

#define NUMBER_PROC_WRITE_PARAMETERS 2
#define VMR_WRITE_CALLBACK test_alloc_runtest
#include "../init/proc.c"

#define VMR_HELP_PROVIDED test_alloc_help
#include "../init/init.c"
