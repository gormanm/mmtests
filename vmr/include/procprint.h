/*
 * procprint
 *
 * This header file contains all the functions and macros related to handling
 * and printing to proc buffers
 *
 * Mel Gorman 2002
 */

#ifndef __PROCPRINT_H_
#define __PROCPRINT_H_

/* Allocation and freeing of proc buffers */
void vmrproc_freebuffer(vmr_desc_t *testinfo);
int  vmrproc_allocbuffer(unsigned int pages, vmr_desc_t *testinfo);
int  vmrproc_growbuffer(unsigned int pages, vmr_desc_t *testinfo);

/* Tests to make sure buffers exist */
#define vmrproc_checkbuffer(x) !(x.procbuf) || x.procbuf_size == 0

/**
 * vmrproc_openbuffer - Attempts to acquire a buffer and clears it
 * @testinfo: The test descriptor
 *
 * When a test begins, this function is called. The lock is acquired and
 * the PID examined. If the PID is 0, there is no writers so this process
 * gets it and is allowed to write. Callers should use vmrproc_closebuffer
 * to ensure the proc buffer is freed
 */
inline int vmrproc_openbuffer(vmr_desc_t *testinfo) {
	unsigned long limit = jiffies;

	spin_lock(&testinfo->lock);
tryagain:
	if (testinfo->pid == 0) { 
		/* We are the new writer */
		testinfo->pid = current->pid;
		testinfo->written = 0;
		if (testinfo->procbuf) {
			memset(testinfo->procbuf, 0, testinfo->procbuf_size);
		}

		spin_unlock(&testinfo->lock);
		return 1;
	}

	/* We failed to get access */
	if (testinfo->flags & VMR_WAITPROC) {
		/* Schedule to give the user a chance to free */
		spin_unlock(&testinfo->lock);
		__set_current_state(TASK_RUNNING);
		schedule();
		spin_lock(&testinfo->lock);

		/* Check the time. Don't wait more than 5 seconds */
		if ((jiffies - limit) / HZ <= 5) goto tryagain;

		printk("Waited 5 seconds for buffer\n");
	}

	printk("WARNING: Cannot acquire buffer to print with\n");

	spin_unlock(&testinfo->lock);
	return 0;
}
		
/**
 * vmrproc_closebuffer - Close access to a proc buffer
 * @testinfo: The test descriptor
 */
inline int __vmrproc_closebuffer(vmr_desc_t *testinfo, int force) {
	if (force == 1 ||
	    testinfo->pid == current->pid || 
	    (testinfo->written < -1 && -testinfo->written == current->pid)) {

		spin_lock(&testinfo->lock);
		testinfo->pid = 0;
		spin_unlock(&testinfo->lock);

		return 1;
	}

	return 0;
}

#define vmrproc_closebuffer(x) __vmrproc_closebuffer(x, 0)
#define vmrproc_closebuffer_nocheck(x) __vmrproc_closebuffer(x, 1)

/*
 * Print macros
 * Because these are macros there is some constraints with using them.
 * 
 * o The vmr_desc_t array describing the tests must be declared static and
 *   called testinfo.
 *
 * o The index in the testinfo[] array been printed to must be called
 *   procentry. If there is only one entry, #define procentry to be 0
 *
 */

/* Simple printk wrapper */
#define vmr_printk(x,args...)      printk("<1>" MODULENAME ": " x, ## args)

/* Wrapper for sprintf to check for buffer overruns */
#define vmr_snprintf(info, x,y,args...) \
	if (current->pid == info->pid) { \
		*print_written += snprintf(x, y, ## args); \
		if (*print_written >= print_size) { \
			vmr_printk("Proc buffer filled!!! Disabling\n"); \
			*print_written= -(info->pid); \
		} \
	}

/* 
 * Print to a procentry. It is presumed the local proc buffer array is
 * called procbuf and it's size is procbuf_size
 */
#define printp_entry(procentry, format, args...) if (testinfo[procentry].written >= 0) { \
	char  *print_buf = testinfo[procentry].procbuf + testinfo[procentry].written; \
	size_t print_len = testinfo[procentry].procbuf_size - testinfo[procentry].written; \
	size_t print_size = testinfo[procentry].procbuf_size; \
	int *print_written = &testinfo[procentry].written; \
	if (print_len > 128) { print_len -= 128; } else { print_len = 0; } \
	                        \
	vmr_snprintf((&testinfo[procentry]),  \
		     print_buf, \
		     print_len, \
		     format,    \
		     ## args);  \
}

#define printp(format, args...) printp_entry(procentry, format, ## args)

int printp_buddyinfo(vmr_desc_t *testinfo, int procentry,
						int attempt, int success);
#endif

/* Extern defines for default proc read/write functions */
extern int vmr_sanity(int *params, int noread);
extern int vmr_read_proc(char *buf, char **start, off_t offset, int count, int *eof, void *data);
extern int vmr_write_proc (struct file *file, const char *buf, unsigned long count, void *data);
