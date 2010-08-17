/**
 * nanotime.h
 * 
 * Support for high-resolution timers
 * TODO: This is x86 specific, make it architecture independant
 */
#ifndef __NANOTIME_H
#define __NANOTIME_H

#ifdef CONFIG_X86
/**
 * rdtsc: Read the current number of clock cycles that have passed
 */
inline unsigned long long read_clockcycles(void)
{
	unsigned long low_time, high_time;
	asm volatile( 
		"rdtsc \n\t" 
			: "=a" (low_time),
			  "=d" (high_time));
        return ((unsigned long long)high_time << 32) | (low_time);
}
#else
#warning read_clockcycles not implemented for this arch
inline unsigned long long read_clockcycles(void)
{
	return jiffies;
}
#endif /* CONFIG_X86 */
#endif /* __NANOTIME_H */
