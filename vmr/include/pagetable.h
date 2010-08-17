/*
 * pagetable.h
 *
 * See src/core/pagetable.c for details
 *
 * Mel Gorman 2002
 */
#ifndef __PAGETABLE_H_
#define __PAGETABLE_H_

/* Return a struct page for an addr */
struct page *get_struct_page(unsigned long addr);

/* For all pte's within the given range, call func() passing it data */
unsigned long forall_pte_mm(struct mm_struct *mm, unsigned long addr,
			unsigned long len, unsigned long *sched_count,
			void *data,
			unsigned long (*func)(pte_t *, unsigned long addr, void *data));

/* Return the number of present pages within a range */
unsigned long countpages_mm(struct mm_struct *mm, unsigned long addr, 
		unsigned long len, unsigned long *sched_count);

/*
 * Print out a map showing present/swapped pages in range. Needs to have the
 * testinfo struct passed in as data
 */
unsigned long vmr_printmap(struct mm_struct *mm, unsigned long addr,
		unsigned long len, unsigned long *sched_count, 
		vmr_desc_t *testinfo);

/*
 * 2.5.32 removed the normal pte_offset and replaced it with a few 
 * different types of pte_offset_kernel . As far as VM Regress is concerned,
 * pte_offset_kernel is more important so if it's defined, we define
 * pte_offset to be it, otherwise we use the pte_offset provided
 */
#ifdef pte_offset_kernel
#define pte_offset(dir, addr) pte_offset_kernel(dir, addr)
#endif

#endif

