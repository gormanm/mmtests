/*
 * proc.c
 *
 * This file is never compiled on its own. It is designed to have all the
 * code needed for reading and writing to proc directories in it. Module
 * modules have essentially the exact same code for this function with
 * only minor differences. It is included with #include which isn't strictly
 * speaking the right way to do it, but it is the simpliest method available
 *
 * The includer of this must make a number of defines
 * VMR_PROC_READ_CALLBACK	- Define to a function should should be called 
 *                                to fill a proc buffer with information. It 
 *                                should take one parameter, the procentry 
 *                                index into testinfo being read
 * VMR_READ_PROC_ENDCALLBACK    - Define that will be included at the end of
 * 				  the read of the proc. Used by mmap benchmark
 * 				  to close a particular proc buffer forcibly
 * NUMBER_PROC_WRITE_PARAMETERS - The number of integers written to a proc 
 *                                entry. If this is not defined, no writeback
 *                                function will be generated
 * VMR_PROC_WRITE_CALLBACK	- Same idea except defined for the write 
 * 				  callback. It takes an array of parameters
 * 				  written from userland, the number of
 * 				  parameters written and the procentry index
 * 				  into testinfo
 * CHECK_PROC_PARAMETERS        - If defined the defined function is called 
 *                                which is expected to return 1 if the
 *                                parameters are sane
 * PARAM_TYPE			- Optional to define the type of parameters
 * 				  being passed. If not specified, it defaults
 * 				  to int
 */

#ifdef MAX_PROC_WRITE
#error MAX_PROC_WRITE already defined
#else
#define MAX_PROC_WRITE 256
#endif

#ifndef PARAM_TYPE
#define PARAM_TYPE int
#endif

/**
 * vmr_read_proc - Routine to call if a proc entry is read from userspace
 * 
 * @buf:    buffer to write to
 * @start:  Local allocated page used for printing large proc entries
 * @offset: Number of bytes read so far
 * @count:  Number of bytes to read
 * @eof:    EOF flag (returned)
 * @data:   Index into testinfo[] array that is being read
 */
int vmr_read_proc(char *buf, char **start, off_t offset, int count, int *eof, void *data)
{
	off_t len;
	int procentry;

	/* The proc entry being read is stored in the private data pointer */
	procentry = *(int *)data;

#ifdef VMR_READ_PROC_CALLBACK
	/* Populate proc buffer */
	if (offset == 0) VMR_READ_PROC_CALLBACK(procentry);
#endif

	/* Sanity check */
	if (offset < 0) {
		vmr_printk("WARNING: Negative offset was passed in. Some sort of bug exists with proc handling\n");
		*eof = 1;
		return 0;
	}

	/* Set start */
	*start = buf;

	/* Get length of proc entry */
	len =  strlen(testinfo[procentry].procbuf);
	if (offset > len) {
		vmr_printk("WARNING: proc offset > buffer length\n");
		return 0;
	}

	/* Make sure we do not try and read off the end */
	if (offset + count > len) {
		count = len - offset;
	}

	/* Set the length that needs to be copied */
	len -= offset;

	/*
	 * Check if
	 *   o this read will be the last read
	 *   o if the reader would go past the buffer end
	 *   o that more than PAGE_SIZE was requested
	 *   o a negative length was asked for
	 */
	if (len <= count) *eof=1;
	if (len > count) len = count;
	if (len > PAGE_SIZE) len = PAGE_SIZE;
	if (len < 0) len = 0;

	/* Copy string into buffer */
	strncpy(buf, (testinfo[procentry].procbuf + offset), len);
	buf[len] = '\0';

#ifdef VMR_READ_PROC_CALLBACK
	if (*eof) vmrproc_closebuffer(&testinfo[procentry]);
#endif

#ifdef VMR_READ_PROC_ENDCALLBACK
	VMR_READ_PROC_ENDCALLBACK;
#endif
	return len;
}

#ifdef NUMBER_PROC_WRITE_PARAMETERS
/**
 * vmr_write_proc - Routine to call if proc entry is written to
 * @file: unused
 * @buffer: user buffer
 * @count: data len
 * @data:  Index into testinfo[] which is being written
 *
 * This function will only exist if NUMBER_PROC_WRITE_PARAMETERS is defined,
 * hence this function is wrapped around an #ifdef
 */
int vmr_write_proc (struct file *file, const char *buf, 
		    unsigned long count, void *data)
{
	char readbuf[MAX_PROC_WRITE];
	char *from = readbuf; 	/* Pointer to beginning of parameter */
	char *to;		/* Pointer to end of parameter */
	PARAM_TYPE params[NUMBER_PROC_WRITE_PARAMETERS]; /* Array of ints read */
	int noread=0;				  /* Number ints read */
	int procentry;

	/* Which proc buffer we are writing to is passed in with *data */
	procentry = *(int *)data;

	/* Clear parameters */
	memset(params, 0, sizeof(params));

	/* Read input */
	if (count >= MAX_PROC_WRITE) {
		vmr_printk("count >= MAX_PROC_WRITE\n");
		return -EINVAL;
	}
	if (copy_from_user(&readbuf, buf, count)) {
		vmr_printk("copy_from_user failed\n");
		return -EFAULT;
	}
	readbuf[count] = '\0';

	while (from && noread < NUMBER_PROC_WRITE_PARAMETERS) {
		/* Split input by the space char */
		to = strchr(from, ' ');
		if (to) *(to++)='\0';

		/* Convert this parameter */
		params[noread] = vmr_strtol(from, NULL, 10);
		
		/* Move to next parameter */
		from = to;
		noread++;
	}

#ifdef CHECK_PROC_PARAMETERS
	/* Sanity check parameters */
	CHECK_PROC_PARAMETERS(params, noread);
#endif

	/* Run the test */
	VMR_WRITE_CALLBACK(params, noread, procentry);

	return count;
}
#endif /* NUMBER_PROC_WRITE_PARAMETERS */
