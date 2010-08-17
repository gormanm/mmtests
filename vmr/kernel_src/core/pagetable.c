/*
 * pagetable - Functions related to page tables
 *
 * These functions are related to walking page tables. They are loosly based
 * on how vmscan uses swap_out_vma but this is pretty standard stuff. There
 * is three main functions provided. They are all pretty expensive so use
 * with care
 *
 * get_struct_page - Returns a struct page for a given address
 * forall_pages_mm - This calls a callback function for every pte within a
 *                   given address range. It will count how many times 
 *                   schedule() was called if requested
 * countpages_mm   - This is a simple use of forall_pages_mm to count how
 *                   many pages are present within a given addresss range
 * 
 * Mel Gorman 2002
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
#include <linux/sched.h>
#include <linux/mmzone.h>
#include <linux/mm.h>
#include <asm/uaccess.h>

/* Module specific */
#include <vmregress_core.h>
#include <procprint.h>
#include <pagetable.h>
#include <linux/highmem.h>
#include <asm/rmap.h>
#include <asm/current.h>

#define MODULENAME "pagetable"
MODULE_AUTHOR("Mel Gorman <mel@csn.ul.ie>");
MODULE_DESCRIPTION("Page Table Related Operations");
MODULE_LICENSE("GPL");

/* RMAP uses pte_offset_map instead of pte_offset. */
#ifdef _I386_RMAP_H
#include <linux/highmem.h>
// #define pte_offset(pmd, addr) pte_offset_map(pmd, addr)
#endif

/**
 * get_struct_page - Gets a struct page for a particular address
 * @address - the address of the page we need
 *
 * Two versions of this function have to be provided for working
 * between the 2.4 and 2.5 kernels. Rather than littering the
 * function with #defines, there is just two separate copies.
 * Look at the one that is relevant to the kernel you're using
 */
struct page *get_struct_page(unsigned long addr)
{
	struct mm_struct *mm;
	pgd_t *pgd;
	pud_t *pud;
	pmd_t *pmd;
	pte_t *ptep, pte;
	unsigned long pfn;
	struct page *page=NULL;

	mm = current->mm;
	/* Is this possible? */
	if (!mm) return NULL;

	spin_lock(&mm->page_table_lock);

	pgd = pgd_offset(mm, addr);
	if (!pgd_none(*pgd) && !pgd_bad(*pgd)) {
		pud = pud_offset(pgd, addr);
		if (!pud_none(*pud) && !pud_bad(*pud)) {
			pmd = pmd_offset(pud, addr);
			if (!pmd_none(*pmd) && !pmd_bad(*pmd)) {
				/*
			 	* disable preemption because of potential kmap().
			 	* page_table_lock should already have disabled
			 	* preemtion.  But, be paranoid.
			 	*/
				preempt_disable();
				ptep = pte_offset_map(pmd, addr);
				pte = *ptep;
				pte_unmap(ptep);
				preempt_enable();
				if (pte_present(pte)) {
					pfn = pte_pfn(pte);
					if (pfn_valid(pfn))
						page = pte_page(pte);
				}
			}
		}
	}

	spin_unlock(&mm->page_table_lock);
	return page;
}

/**
 * forall_pte_pmd - Excute a function func for all pages within a range
 * @mm: mm been examined
 * @pmd: The PGD been examined
 * @start: The starting address
 * @end: The end address
 * @sched_count: A running count of how many times schedule() was called
 * @data: A pointer to caller data
 * @func: The function to call
 *
 * This function can context switch and/or block.  So whoever
 * calls this had better be certain the mm_struct being examined
 * isn't changing out from underneath us.
 *
 * TODO: increment the mm_struct usage count or things could go very wrong
 *       Probably just lucky up until this point but it probably explains
 *       some hard to reproduce bugs I remember from the dawn of time
*/

/*
 * Again because of the changes in page table walking, a 2.4 and 2.5
 * version is supplied
 */
inline unsigned long forall_pte_pmd(struct mm_struct *mm, pmd_t *pmd, 
		unsigned long start, unsigned long end, 
		unsigned long *sched_count,
		void *data,
		unsigned long (*func)(pte_t *, unsigned long, void *))
{
	
	pte_t *ptep, pte;
	unsigned long pmd_end;
	unsigned long ret=0;

	if (pmd_none(*pmd)) return 0;

	pmd_end = (start + PMD_SIZE) & PMD_MASK;
	if (end > pmd_end) end = pmd_end;

	do {
		preempt_disable();
		ptep = pte_offset_map(pmd, start);
		pte = *ptep;
		pte_unmap(ptep);
		preempt_enable();

		/* Call the if a PTE is available */
		if (!pte_none(pte)) {

			/*
			 * Call schedule if necessary
			 *	Can func() block or be preempted?
			 *	It seems the sched_count won't be guarnateed
			 *	accurate.
			 */
			spin_unlock(&mm->page_table_lock);
			check_resched(sched_count);
			ret += func(&pte, start, data);
			spin_lock(&mm->page_table_lock);
		}
		start += PAGE_SIZE;
	} while (start && (start < end));

	return ret;
}

/**
 * forall_pte_pud - Execute a function func for all pages within a range
 * @pud: The PUD been examined
 * @start: The starting address
 * @end: The end address
 * @sched_count: A running count of how many times schedule() was called
 * @data: Pointer to caller data
 * @func: The function to call
 */
inline unsigned long forall_pte_pud(struct mm_struct *mm, pud_t *pud, 
		unsigned long start, unsigned long end, 
		unsigned long *sched_count, void *data,
		unsigned long (*func)(pte_t *, unsigned long, void *)) {
	
	pmd_t *pmd;
	unsigned long pud_end;
	unsigned long ret=0;

	if (pud_none(*pud)) return 0;

	pmd = pmd_offset(pud, start);
	if (!pmd) return 0;

	pud_end = (start + PUD_SIZE) & PUD_MASK;
	if (end > pud_end) end = pud_end;

	do {
		if (!pmd_none(*pmd) ) ret += forall_pte_pmd(mm, pmd, start, end, sched_count, data, func);

		start = (start + PMD_SIZE) & PMD_MASK;
		pmd++;
	} while (start && (start < end));

	return ret;
}



/**
 * forall_pte_pgd - Execute a function func for all pages within a range
 * @pgd: The PGD been examined
 * @start: The starting address
 * @end: The end address
 * @sched_count: A running count of how many times schedule() was called
 * @data: Pointer to caller data
 * @func: The function to call
 */
inline unsigned long forall_pte_pgd(struct mm_struct *mm, pgd_t *pgd, 
		unsigned long start, unsigned long end, 
		unsigned long *sched_count, void *data,
		unsigned long (*func)(pte_t *, unsigned long, void *)) {
	
	pud_t *pud;
	unsigned long pgd_end;
	unsigned long ret=0;

	if (pgd_none(*pgd)) return 0;

	pud = pud_offset(pgd, start);
	if (!pud) return 0;

	pgd_end = (start + PGDIR_SIZE) & PGDIR_MASK;
	if (end > pgd_end) end = pgd_end;

	do {
		if (!pud_none(*pud) ) ret += forall_pte_pud(mm, pud, start, end, sched_count, data, func);

		start = (start + PUD_SIZE) & PUD_MASK;
		pud++;
	} while (start && (start < end));

	return ret;
}

/**
 * forall_pte_mm - Execute a function func for all pages within a range
 * @mm: The memory area been examined
 * @addr: The starting address
 * @len: The size of the area to count pages in
 * @sched_count: A running count of how many times schedule() was called
 * @data: Pointer to caller data
 * @func: The function to call
 *
 * This function presumes it will be called for an addr and len
 * with a valid vma.
 *
 */
unsigned long forall_pte_mm(struct mm_struct *mm, unsigned long addr, 
		unsigned long len, unsigned long *sched_count,
		void *data,
		unsigned long (*func)(pte_t *, unsigned long, void *)) {

	unsigned long ret=0;		/* Page count */
	unsigned long end;		/* Start and end of a area */

	pgd_t *pgd=NULL;

	if (!mm) return 0;
	if (!func) return 0;

	end = addr + len;

	/* Lock page tables */
	spin_lock(&mm->page_table_lock);

	/* Cycle through all PGD's */
	pgd = pgd_offset(mm, addr);
	if (pgd_none(*pgd)) return 0;

	do {
		ret += forall_pte_pgd(mm, pgd, addr, end, sched_count, data, func);
		
		/* Move to next PGD */
		addr = (addr + PGDIR_SIZE) & PGDIR_MASK;
		pgd++;

	} while (addr && (addr < end));

	spin_unlock(&mm->page_table_lock);

	return ret;
}

/**
 * ispage_present - Returns 1 if a pte is present in memory
 * @pte: The pte been examined
 * @addr: The address the pte is at (unused)
 * @data: Pointer to user data (unused)
 *
 * This is a callback function for forall_pages_mm() to use.
 */
unsigned long ispage_present(pte_t *pte, unsigned long addr, void *data) {
	if (pte_present(*pte)) return 1;
	return 0;
}

/**
 * countpages_mm - Count how many pages are present in a mm
 * @mm: The mm to count pages in
 * @addr: The starting address
 * @len: The length of the address space to check
 * @sched_count: A count of how many times schedule() was called
 */
unsigned long countpages_mm(struct mm_struct *mm, unsigned long addr,
		unsigned long len, unsigned long *sched_count) {

	return forall_pte_mm(mm, addr, len, sched_count, NULL, ispage_present);
}

/**
 * vmr_printpage - Sets the corresponding bit in the proc buffer (callback)
 * @pte: The pte been examined
 * @addr: The address the pte is at
 * @data: Pointer to user data (vmr_desc_t)
 *
 * This is the callback for the pagetable walk. It will set the appropriate
 * bit in the proc buffer. The beginning of the map is presumed to be 
 * testinfo->written is pointing to
 */
unsigned long vmr_printpage(pte_t *pte, unsigned long addr, void *data) {
	vmr_desc_t *testinfo;	/* Test Descriptor */
	int index;		/* Index as an offset from written */
	int bitidx;		/* Which bit within the index for this page */
	int present;

	/* Get the test descriptor */
	testinfo = (vmr_desc_t *)data;

	/* Calculate the index and bit offset */
	index = (addr - testinfo->mapaddr) / PAGE_SIZE;

	bitidx = index % 4;
	index /= 4;

	/* Set the bit */
	present = pte_present(*pte) ? 1 : 0;
	testinfo->procbuf[testinfo->written + index] |= present << bitidx;
	
	/* Return page present to give a running count of present pages */
	return present;
}

/**
 * vmr_printmap - Print out a map representing a memory range
 * @mm: The mm to print pages from
 * @addr: The starting address
 * @len: The len of the address space to print
 * @sched_count: A count of how many times schedule() was called
 *
 * This function is used when it is desirable to see what a memory area
 * looks like. Each character in the map has 8 bits. The lower four bits
 * are used to store information about 4 pages. The 5th and 6th bit is set to one.
 * This will guarentee that something printable will show up. Using the
 * whole character for 8 bits leads to unprintable data filled with escape
 * characters.
 */
unsigned long vmr_printmap(struct mm_struct *mm, unsigned long addr,
		unsigned long len, unsigned long *sched_count,
		vmr_desc_t *testinfo)
{
	int mapsize;		/* Size of map */
	int growsize;		/* Number of pages to grow proc */
	int *print_written;	/* Number of bytes written see vmr_snprintf macro*/
	int print_size;	/* Size of proc buffer, see vmr_snprinf macro */
	int present;

	/* Make sure we are the writer */
	if (current->pid != testinfo->pid) return 0;

	print_written = &testinfo->written;
	print_size    = testinfo->procbuf_size;

	/* Calculate if the current proc area needs to be grown 
	 * Each 8 pages is one character hence 
	 *   (len / PAGE_SIZE) gives the number of pages
	 *   no. pages / 4 = number of chars (using only readable chars)
	 */
	mapsize = ((len / PAGE_SIZE) / 4);

	/*
	 * check if we should grow the proc buffer 
	 * The additional 256 bytes is for the header and footer around
	 * the map information
	 * */
	if (testinfo->procbuf_size - *print_written < mapsize + 256) {
		/* Proc buffer has to be grown */
		growsize = PAGE_ALIGN(mapsize + 256) / PAGE_SIZE;
		vmr_printk("Growing proc buffer by %d pages for mapsize %d\n", growsize, mapsize);
		vmrproc_growbuffer(growsize, testinfo);
		print_size = testinfo->procbuf_size;
	}

	/* Zero out the map */
	memset(&testinfo->procbuf[*print_written], 0, mapsize);

	/* Print out header for map (40 is for the actual message to print) */
	vmr_snprintf(testinfo,
			&testinfo->procbuf[*print_written],
			testinfo->procbuf_size - *print_written - 40,
			"BEGIN PAGE MAP 0x%lX - 0x%lX\n",
			addr,
			addr + len);

	/* Set the 5th and 6th bit on the map */
	memset(&testinfo->procbuf[*print_written], 48, mapsize);

	/* Print out the map */
	testinfo->mapaddr = addr;
	present = forall_pte_mm(mm, addr, len, sched_count, testinfo, vmr_printpage);

	/* Print out footer (50 is for the message to print) */
	*print_written += mapsize;
	vmr_snprintf(testinfo,
			&testinfo->procbuf[*print_written],
			testinfo->procbuf_size - *print_written - 50,
			"\nEND PAGE MAP - %d pages of %lu present\n", 
			present, len / PAGE_SIZE);

	return 0;
}

/* Export the relevant symbols */
EXPORT_SYMBOL(get_struct_page);
EXPORT_SYMBOL(forall_pte_mm);
EXPORT_SYMBOL(countpages_mm);
EXPORT_SYMBOL(vmr_printmap);

/* Module init */
#define VMR_MODULE_HAS_NO_PROC_ENTRIES
#include "../init/init.c"
