/*
 * init.c
 *
 * This file is never compiled on its own. It is designed to have all the
 * module initialisation code used by every other module to be here cutting
 * down on the amount of code duplication. It is #included by modules
 * which need it with a simple #include directive. This is not great 
 * programming strictly speaking but it is the handiest way to include
 * stub code which changes slightly between modules without the requirement
 * of callback functions
 *
 * The initialisation of a module is concerned with the creation of the
 * proper /proc entries. To have them created, the testinfo[] array which
 * contains all information about different tests is examined to see what
 * proc entries should be created and how
 *
 */

#include <linux/init.h>

#ifndef PROCBUF_INIT_PAGES
#define PROCBUF_INIT_PAGES 1
#endif
/**
 *
 * init_module - Initialise module
 *
 * An including module can define VMR_MODULE_HAS_NO_PROC_ENTRIES if there
 * is no proc entries to be created at all which is used by pagetable.c .
 * If no file entries are to be created, define VMR_MODULE_HAS_NO_FILE_ENTRIES
 * which is only used by vmregress_core.c
 *
 * If VMR_HELP_PROVIDED is defined, the macro will be executed. It is 
 * expected that modules which use this will define the macro to be
 * a function which writes a help information message into the proc entry.
 * See alloc.c for example
 */
int vmr_init_module(void) {
#ifndef VMR_MODULE_HAS_NO_PROC_ENTRIES
	int procentry=0;
	vmr_desc_t *entry = &testinfo[0];

	/* Cycle through all entries */
	for (procentry=0; procentry<NUM_PROC_ENTRIES;procentry++) {
		entry = &testinfo[procentry];
		/*
		 * If a read procedure is supplied, it is a file entry,
		 * otherwise it is a directory entry 
		 */
#ifndef VMR_MODULE_HAS_NO_FILE_ENTRIES
		if (entry->read_proc) {
			struct proc_dir_entry *direntry;

			/* Create a proc entry of requested permissions */
			direntry = create_proc_read_entry(
					entry->name,
					0666,
					vmregress_proc_dir,
					entry->read_proc,
					(void *)&testinfo[procentry].procentry);

			/* Create the write procedure if it exists */
			if (entry->write_proc) 
				direntry->write_proc = entry->write_proc;

			/* Allocate buffer for writing to */
			if (vmrproc_allocbuffer(PROCBUF_INIT_PAGES, &testinfo[procentry])) {
				goto freebuffers;
			}

#ifdef VMR_HELP_PROVIDED
			VMR_HELP_PROVIDED(procentry);
#endif

		} else {
#endif
			/* Create vmregress proc directory */
			vmregress_proc_dir = proc_mkdir("vmregress", 0);
			if (!vmregress_proc_dir) {
				vmr_printk("Failed to create vmregress proc directory");
				return -ENOMEM;
			}
#ifndef VMR_MODULE_HAS_NO_FILE_ENTRIES
		}
#endif
	}
#endif

	vmr_printk("loaded\n");
	return 0;

#ifndef VMR_MODULE_HAS_NO_PROC_ENTRIES
#ifndef VMR_MODULE_HAS_NO_FILE_ENTRIES
freebuffers:
	 /* Failure patch, remove all created proc entries */
	vmr_printk("Failed to create all proc entries. out of memory\n");
	while (--procentry >= 0) {
		entry--;
		vmrproc_freebuffer(&testinfo[procentry]);
		remove_proc_entry(entry->name, vmregress_proc_dir);
	}
	return -ENOMEM;
#endif
#endif
}

/**
 * vmr_cleanup_module - Unload a module
 * 
 * This is called during module unload. Every proc entry that has been
 * registered by this module will be deleted and the associated proc
 * buffer freed
 */
void vmr_cleanup_module(void) {
#ifndef VMR_MODULE_HAS_NO_PROC_ENTRIES
	vmr_desc_t *entry = &testinfo[0];
	int procentry=0;
	for (procentry=0; procentry<NUM_PROC_ENTRIES; procentry++,entry++) {
#ifndef VMR_MODULE_HAS_NO_FILE_ENTRIES
		if (entry->read_proc) {
			/* Delete proc entry */
			remove_proc_entry(entry->name, vmregress_proc_dir);
			vmrproc_freebuffer(&testinfo[procentry]);
		} else {
#endif
			/* Delete proc directory */
			remove_proc_entry(entry->name, 0);
#ifndef VMR_MODULE_HAS_NO_FILE_ENTRIES
		}
#endif

	}
#endif

	vmr_printk("unloaded\n");
}

module_init(vmr_init_module);
module_exit(vmr_cleanup_module);
