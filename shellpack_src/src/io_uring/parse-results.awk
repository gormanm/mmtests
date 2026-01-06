#!/usr/bin/awk -f

BEGIN {
	mult["K"] = 1
	mult["M"] = 1000
	nr_sample = 0
}

/IOPS=/ {
	match($0, /=([0-9.]+)([A-Z])/, arr)
	val=arr[1]*mult[arr[2]]
	nr_sample++
	print "IOops\t_\t_\t"nr_sample"\t"val"\t_"
}

