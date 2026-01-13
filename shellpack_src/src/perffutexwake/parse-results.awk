#!/usr/bin/awk -f

/: Wokeup/ {
	sub(/.*threads in/, "", $0)
	print "wake-latency\t"threads"\t_\t"iteration"\t"($1*1000)"\t_"
}
